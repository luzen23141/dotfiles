# 直接用 a 指令呼叫，a 應已定義在 alias 內
# alias a="python3 $(echo $DOTFILES)/bin/a.py"
import os
import shutil
import subprocess
import sys


def main():
    if len(sys.argv) < 2:
        print("缺少參數")
        return

    script_full_name = os.path.basename(sys.argv[0])
    script_name = os.path.splitext(script_full_name)[0]

    command = sys.argv[1]
    parameters = sys.argv[2:]

    # 建立要執行的指令清單
    command_list = [f"{script_name}-{command}"] + parameters

    try:
        # 檢查指令是否存在
        if not shutil.which(f"{script_name}-{command}"):
            print(f"錯誤：{script_name}-{command} 不存在")
            return
        # 使用 subprocess 執行指令
        print(f"執行指令：{' '.join(command_list)}")
        subprocess.run(command_list, check=True)
    except subprocess.CalledProcessError:
        print("指令執行失敗")
    except KeyboardInterrupt:
        print("\n使用者中斷")


main()
