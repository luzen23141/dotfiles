import os
import subprocess
from dataclasses import dataclass

import yaml


@dataclass
class FolderListClass:
    git_folder: dict
    symlink_data: dict
    copy_data: dict


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
    folder_list = FolderListClass(git_folder={}, symlink_data={}, copy_data={})

    def traverse(sub_data, path=""):
        """
        遞迴遍歷 YAML 數據並構建 key-value 結構。

        Args:
          sub_data: YAML 數據。
          path: 當前文件夾路徑。
        """
        for key, value in sub_data.items():

            if not isinstance(value, dict):
                print(f"Warning: Invalid value for {key} in {path}.")
                continue

            if (not isinstance(value.get("type"), str) or
                    not isinstance(value.get("path"), str)):
                new_path = os.path.join(path, key)
                traverse(value, new_path)
                continue

            match value.get("type"):
                case "git":
                    folder_list.git_folder.setdefault(path, {})[key] = value.get("path")
                case "symlink":
                    folder_list.symlink_data.setdefault(path, {})[key] = value.get("path")
                case "copy":
                    folder_list.copy_data.setdefault(path, {})[key] = value.get("path")
                case _:
                    print(f"Warning: Invalid type for {key} in {path}.")

    traverse(data)
    return folder_list


def create_folders_and_clone(data: FolderListClass):
    """
    在 home 目錄下創建文件夾並從 git 倉庫克隆代碼。

    Args:
      data: 包含 key-value 結構的字典。
    """
    home_dir = os.path.expanduser('~')  # 获取 home 目录路径

    for folder_path, git_data in data.git_folder.items():
        full_path = os.path.join(home_dir, folder_path)
        os.makedirs(full_path, exist_ok=True)

        for folder, git_url in git_data.items():
            if not os.path.exists(os.path.join(full_path, folder)):
                subprocess.run(['git', 'clone', git_url, folder], cwd=full_path)


if __name__ == "__main__":
    config_path = os.path.join(os.getenv("ICLOUD_DATA"), "code_folder.yaml")
    yaml_data = process_yaml(config_path)
    # print(yaml_data)
    create_folders_and_clone(yaml_data)
