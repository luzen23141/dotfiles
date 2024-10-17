import os
import subprocess

import yaml


def process_yaml(yaml_file):
    """
    讀取 YAML 文件並將其轉換為 key-value 結構，其中 key 是文件夾路徑，value 是 git 倉庫 URL。

    Args:
      yaml_file: YAML 文件的路徑。

    Returns:
      一個字典，其中包含 key-value 結構。
    """

    with open(yaml_file, 'r') as f:
        data = yaml.safe_load(f)

    result = {}

    def traverse(data, path=""):
        """
        遞迴遍歷 YAML 數據並構建 key-value 結構。

        Args:
          data: YAML 數據。
          path: 當前文件夾路徑。
        """
        for key, value in data.items():
            if isinstance(value, dict):
                new_path = os.path.join(path, key)
                traverse(value, new_path)
            else:
                tmp = {}
                if path in result:
                    tmp = result[path]
                tmp[key] = value
                result[path] = tmp

    traverse(data)
    return result


def create_folders_and_clone(home_dir, data):
    """
    在 home 目錄下創建文件夾並從 git 倉庫克隆代碼。

    Args:
      home_dir: home 目錄的路徑。
      data: 包含 key-value 結構的字典。
    """

    for folder_path, git_data in data.items():
        full_path = os.path.join(home_dir, folder_path)
        os.makedirs(full_path, exist_ok=True)

        for folder, git_url in git_data.items():
            if os.path.exists(os.path.join(full_path, folder)):
                continue
            subprocess.run(['git', 'clone', git_url, folder], cwd=full_path)

if __name__ == "__main__":
    # yaml_file = 'aaa.yaml'
    yaml_file = os.path.join(os.getenv("ICLOUD_DATA"), "code_folder.yaml")
    home_dir = os.path.expanduser('~')  # 获取 home 目录路径

    data = process_yaml(yaml_file)
    create_folders_and_clone(home_dir, data)
