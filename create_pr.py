#!/usr/bin/env python3
import os, sys, json, base64, urllib.request, urllib.parse, ssl

def read_git_remote(path):
    cfg = os.path.join(path, '.git', 'config')
    with open(cfg, 'r') as f:
        for line in f:
            line=line.strip()
            if line.startswith('url ='):
                url=line.split('=',1)[1].strip()
                return url
    return None


def parse_repo_from_url(url):
    # expected formats: https://<token>@github.com/owner/repo.git or https://github.com/owner/repo.git
    if url.startswith('git@'):
        # git@github.com:owner/repo.git
        parts = url.split(':',1)[1]
        if parts.endswith('.git'):
            parts = parts[:-4]
        return parts
    if url.startswith('https://') or url.startswith('http://'):
        # remove credentials if present
        if '@' in url:
            url = url.split('@',1)[1]
        # now github.com/owner/repo.git or github.com/owner/repo
        # remove any protocol prefix
        if url.startswith('github.com/'):
            path = url[len('github.com/'):]
        else:
            # maybe full https://github.com/owner/repo.git
            parsed = urllib.parse.urlparse('https://'+url) if not url.startswith('http') else urllib.parse.urlparse(url)
            path = parsed.path.lstrip('/')
        if path.endswith('.git'):
            path = path[:-4]
        return path
    return None


def gh_api_request(method, endpoint, data=None):
    token = os.environ.get('GH_TOKEN')
    if not token:
        print('GH_TOKEN not set', file=sys.stderr); sys.exit(1)
    url = 'https://api.github.com' + endpoint
    headers = {'Authorization': 'token ' + token, 'User-Agent': 'spacebot-agent'}
    if data is not None:
        body = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    else:
        body = None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        try:
            err = e.read().decode()
            print('HTTP error', e.code, err, file=sys.stderr)
        except:
            print('HTTP error', e.code, file=sys.stderr)
        sys.exit(1)


def main():
    repo_path = '/data/agents/main/workspace/spacebot-blog'
    remote_url = read_git_remote(repo_path)
    if not remote_url:
        print('Could not find remote url in .git/config', file=sys.stderr); sys.exit(1)
    repo = parse_repo_from_url(remote_url)
    if not repo:
        print('Could not parse repo from url: ' + remote_url, file=sys.stderr); sys.exit(1)
    owner_repo = repo
    print('Repo:', owner_repo)

    # get main commit sha
    ref = gh_api_request('GET', f'/repos/{owner_repo}/git/ref/heads/main')
    main_commit_sha = ref['object']['sha']
    print('Main commit sha:', main_commit_sha)
    commit = gh_api_request('GET', f'/repos/{owner_repo}/git/commits/{main_commit_sha}')
    main_tree_sha = commit['tree']['sha']
    print('Main tree sha:', main_tree_sha)

    # collect files
    tree = []
    for root, dirs, files in os.walk(repo_path):
        # skip .git
        dirs[:] = [d for d in dirs if d != '.git']
        for fn in files:
            absf = os.path.join(root, fn)
            rel = os.path.relpath(absf, repo_path)
            # skip any files outside? already under repo_path
            # read bytes and create blob
            with open(absf, 'rb') as f:
                data = f.read()
            b64 = base64.b64encode(data).decode('ascii')
            blob = gh_api_request('POST', f'/repos/{owner_repo}/git/blobs', {
                'content': b64,
                'encoding': 'base64'
            })
            blob_sha = blob['sha']
            mode = '100644'
            # check executable
            if os.access(absf, os.X_OK):
                mode = '100755'
            tree.append({'path': rel.replace('\\','/'), 'mode': mode, 'type': 'blob', 'sha': blob_sha})
            print('Created blob for', rel)

    # create new tree
    new_tree = gh_api_request('POST', f'/repos/{owner_repo}/git/trees', {
        'tree': tree,
        'base_tree': main_tree_sha
    })
    new_tree_sha = new_tree['sha']
    print('New tree sha:', new_tree_sha)

    commit_message = 'Redesign: minimal header, dark theme, centered layout, simple post list'
    new_commit = gh_api_request('POST', f'/repos/{owner_repo}/git/commits', {
        'message': commit_message,
        'tree': new_tree_sha,
        'parents': [main_commit_sha]
    })
    new_commit_sha = new_commit['sha']
    print('New commit sha:', new_commit_sha)

    branch_name = 'redesign/base-layout'
    # create ref
    ref_resp = gh_api_request('POST', f'/repos/{owner_repo}/git/refs', {
        'ref': 'refs/heads/' + branch_name,
        'sha': new_commit_sha
    })
    print('Created ref for branch', branch_name)

    # create pull request
    pr = gh_api_request('POST', f'/repos/{owner_repo}/pulls', {
        'title': commit_message,
        'head': branch_name,
        'base': 'main',
        'body': 'Automated PR: apply redesign changes (header, dark theme, layout, post list)'
    })
    print('PR url:', pr.get('html_url'))
    # Output machine-readable
    out = {'pr_url': pr.get('html_url'), 'branch': branch_name}
    print(json.dumps(out))

if __name__ == '__main__':
    main()
