#!/usr/bin/env python3
import re
import sys

def fix_setup_teardown(content):
    # Pattern to fix @MainActor async setUp
    setup_pattern = r'@MainActor\s+override func setUp\(\) async throws \{\s*try await super\.setUp\(\)(.*?)\}'
    
    def fix_setup(match):
        body = match.group(1).strip()
        return f'''override func setUp() {{
        super.setUp()
        MainActor.assumeIsolated {{
{body}
        }}
    }}'''
    
    # Pattern to fix @MainActor async tearDown
    teardown_pattern = r'@MainActor\s+override func tearDown\(\) async throws \{(.*?)try await super\.tearDown\(\)\s*\}'
    
    def fix_teardown(match):
        body = match.group(1).strip()
        return f'''override func tearDown() {{
        MainActor.assumeIsolated {{
{body}
        }}
        super.tearDown()
    }}'''
    
    # Apply fixes
    content = re.sub(setup_pattern, fix_setup, content, flags=re.DOTALL)
    content = re.sub(teardown_pattern, fix_teardown, content, flags=re.DOTALL)
    
    return content

def process_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    modified_content = fix_setup_teardown(content)
    
    if modified_content != content:
        with open(file_path, 'w') as f:
            f.write(modified_content)
        print(f"Fixed: {file_path}")
    else:
        print(f"No changes: {file_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_setup_assume_isolated.py <file1> [file2] ...")
        sys.exit(1)
    
    for file_path in sys.argv[1:]:
        process_file(file_path)