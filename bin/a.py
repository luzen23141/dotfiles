# 直接用a 指令調用，a 應該已經定義在alias內
# alias a="python3 $(echo $DOTFILES)/bin/a.py"
import os
import subprocess
import sys


def main():
    if len(sys.argv) < 2:
        print("缺少參數")
        return

    script_fall_name = os.path.basename(sys.argv[0])
    script_name = os.path.splitext(script_fall_name)[0]

    command = sys.argv[1]
    parameters = sys.argv[2:]

    # 构建要执行的命令列表
    command_list = [f"{script_name}-{command}"] + parameters

    try:
        # 使用subprocess模块执行命令
        print(f"執行指令：{' '.join(command_list)}")
        subprocess.run(command_list, check=True)
    except subprocess.CalledProcessError:
        print("指令執行失敗")


main()
