# 直接用 a 指令呼叫，a 應已定義在 alias 內
# alias a="python3 $(echo $DOTFILES)/bin/a.py"
import os
import shutil
import subprocess
import sys


def resolve_subcommand(script_name, command):
    """優先 $DOTFILES/bin，其次與 a.py 同目錄，最後才查 PATH。"""
    name = f"{script_name}-{command}"
    candidates = []

    dotfiles = os.environ.get("DOTFILES")
    if dotfiles:
        candidates.append(os.path.join(dotfiles, "bin", name))

    here = os.path.dirname(os.path.abspath(__file__))
    candidates.append(os.path.join(here, name))

    for path in candidates:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path

    return shutil.which(name)


def main():
    if len(sys.argv) < 2:
        print("缺少參數")
        sys.exit(1)

    script_full_name = os.path.basename(sys.argv[0])
    script_name = os.path.splitext(script_full_name)[0]

    command = sys.argv[1]
    parameters = sys.argv[2:]
    subcommand = f"{script_name}-{command}"
    resolved = resolve_subcommand(script_name, command)

    try:
        if not resolved:
            print(f"錯誤：{subcommand} 不存在")
            sys.exit(1)
        command_list = [resolved] + parameters
        print(f"執行指令：{subcommand}{' ' if parameters else ''}{' '.join(parameters)}")
        subprocess.run(command_list, check=True)
    except subprocess.CalledProcessError as e:
        print("指令執行失敗")
        sys.exit(e.returncode or 1)
    except KeyboardInterrupt:
        print("\n使用者中斷")
        sys.exit(130)


if __name__ == "__main__":
    main()
