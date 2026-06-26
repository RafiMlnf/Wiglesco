with open("d:/Coding/Stereogram/apps/web/app/page.tsx", "r", encoding="utf-8") as f:
    content = f.read()

start_idx = content.find("return (")
return_content = content[start_idx:]

stack = []
for i, c in enumerate(return_content):
    line = content[:start_idx + i].count(chr(10)) + 1
    if c == '{':
        stack.append(line)
    elif c == '}':
        if not stack:
            print(f"Error: Extra closing brace at line {line}")
        else:
            stack.pop()

if stack:
    print(f"Error: Unclosed braces opened at lines: {stack}")
else:
    print("Braces are balanced inside the return block!")
