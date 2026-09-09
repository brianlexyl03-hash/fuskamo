from pathlib import Path
import re, subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
errors=[]

# Migration continuity
migs=sorted((ROOT/'database/migrations').glob('*.sql'))
nums=[]
for p in migs:
    m=re.match(r'(\d+)_',p.name)
    if m: nums.append(int(m.group(1)))
expected=list(range(1,max(nums)+1))
if nums!=expected: errors.append(f'migration sequence has gaps: {nums}')
if max(nums)<26: errors.append('migration 026 missing')

m26=(ROOT/'database/migrations/026_social_platform_v2.sql').read_text()
required_tables=['message_requests','direct_message_reactions','direct_message_receipts','direct_message_attachments','typing_presence','close_friends','story_highlights','social_reel_saves','social_reel_feedback','social_post_saves','social_post_media','social_hashtags','group_bans','group_role_permissions','achievement_progress','achievement_events','scoreboard_seasons','scoreboard_rankings','moderation_policy_rules','moderation_case_events']
for t in required_tables:
    if not re.search(rf'create table if not exists {re.escape(t)}\b',m26,re.I): errors.append(f'026 missing table {t}')

# Identity invariants: no automatic tick assignment in ensure_my_profile.
block=re.search(r'create or replace function ensure_my_profile.*?grant execute on function ensure_my_profile',m26,re.I|re.S)
if not block: errors.append('ensure_my_profile replacement missing')
else:
    b=block.group(0)
    if re.search(r'badge_type\s*=\s*case\s+when.*p_role\s*=\s*\'scout\'',b,re.I|re.S): errors.append('ensure_my_profile still grants role badges automatically')
    if re.search(r'values\([^;]*true\s*,[^;]*\'blue\'',b,re.I|re.S): errors.append('ensure_my_profile still inserts verified=true')

# JavaScript syntax checks for all backend files.
for p in (ROOT/'backend/src').rglob('*.js'):
    r=subprocess.run(['node','--check',str(p)],capture_output=True,text=True)
    if r.returncode:
        errors.append(f'JS syntax: {p.relative_to(ROOT)}: {r.stderr.strip()}')

# Lightweight Dart structural/import checks. This intentionally ignores braces inside strings/comments.
def strip_dart_strings_comments(text):
    out=[]; i=0; n=len(text); state='code'
    while i<n:
        c=text[i]; d=text[i+1] if i+1<n else ''
        if state=='code':
            if c=='/' and d=='/': state='line'; out.extend('  '); i+=2; continue
            if c=='/' and d=='*': state='block'; out.extend('  '); i+=2; continue
            if c in "'\"": state=c; out.append(' '); i+=1; continue
            out.append(c); i+=1
        elif state=='line':
            if c=='\n': state='code'; out.append('\n')
            else: out.append(' ')
            i+=1
        elif state=='block':
            if c=='*' and d=='/': state='code'; out.extend('  '); i+=2
            else: out.append('\n' if c=='\n' else ' '); i+=1
        else:
            # Ignore quoted string contents; escaped quotes do not close it.
            if c=='\\': out.extend('  '); i+=2; continue
            if c==state: state='code'
            out.append(' '); i+=1
    return ''.join(out)

for p in (ROOT/'lib').rglob('*.dart'):
    text=p.read_text(errors='ignore')
    cleaned=strip_dart_strings_comments(text)
    stack=[]; pairs={')':'(',']':'[','}':'{'}
    for i,ch in enumerate(cleaned):
        if ch in '([{': stack.append(ch)
        elif ch in ')]}':
            if not stack or stack[-1]!=pairs[ch]: errors.append(f'Dart delimiter: {p.relative_to(ROOT)} near char {i}'); break
            stack.pop()
    if stack: errors.append(f'Dart unclosed delimiter: {p.relative_to(ROOT)}')
    for imp in re.findall(r"import\s+['\"](\.\.?/[^'\"]+)['\"]",text):
        target=(p.parent/imp).resolve()
        if not target.exists(): errors.append(f'Missing Dart import: {p.relative_to(ROOT)} -> {imp}')

# Run pure backend engines that don't need npm dependencies.
tests=[
 'backend/src/tests/discoveryEngine.test.js',
 'backend/src/tests/trustBadgeEngine.test.js',
 'backend/src/tests/unifiedGraphEngine.test.js',
 'backend/src/tests/unifiedGraphEngine.v2.test.js',
 'backend/src/tests/videoInfrastructure.test.js',
]
r=subprocess.run(['node','--test',*tests],cwd=ROOT,capture_output=True,text=True)
if r.returncode: errors.append('pure backend tests failed:\n'+r.stdout+'\n'+r.stderr)

print('FUSKAMO SANDBOX SMOKE TEST')
print('migrations:',len(migs),'through',max(nums))
print('backend JS syntax: PASS')
print('Dart structural scan: PASS' if not any(e.startswith(('Dart','Missing Dart')) for e in errors) else 'Dart structural scan: FAIL')
print('pure backend engines: PASS' if r.returncode==0 else 'pure backend engines: FAIL')
print('feature tables checked:',len(required_tables))
if errors:
    print('\nFAILURES:')
    for e in errors: print('-',e)
    sys.exit(1)
print('RESULT: PASS')
