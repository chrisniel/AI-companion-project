import os
import re

def validate_markdown():
    docs_dir = 'docs'
    issues = []
    adr_files = set([f for f in os.listdir('docs/04_Architecture/decisions') if f.endswith('.md')])
    
    for root, _, files in os.walk(docs_dir):
        if 'node_modules' in root or '.git' in root:
            continue
        for file in files:
            if not file.endswith('.md'):
                continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check control chars
            if re.search(r'[\x00-\x08\x0B\x0C\x0E-\x1F]', content):
                issues.append(f"{path}: contains non-printable control characters")
                
            # Check H1 titles
            h1s = re.findall(r'^#\s+(.+)$', content, re.MULTILINE)
            if len(h1s) > 1:
                issues.append(f"{path}: multiple H1 titles found: {h1s}")
                
            # Check relative links (basic)
            links = re.findall(r'\]\(([^http].*?)\)', content)
            for link in links:
                if link.startswith('#'): continue
                link_path = link.split('#')[0]
                if not link_path.endswith('.md') and not link_path.endswith('.png') and '.' in link_path:
                    pass
                if link_path.endswith('.md'):
                    target_path = os.path.normpath(os.path.join(root, link_path))
                    if not os.path.exists(target_path):
                        issues.append(f"{path}: broken relative link to {link_path} (resolved {target_path})")
                
                # Check ADR filenames specifically
                if 'ADR-' in link_path:
                    adr_name = os.path.basename(link_path)
                    if adr_name not in adr_files and adr_name.endswith('.md'):
                        issues.append(f"{path}: references non-existent ADR {adr_name}")

    if not issues:
        print("Validation Passed: No issues found.")
    else:
        print("Validation Issues:")
        for issue in issues:
            print(issue)

validate_markdown()
