import os
import subprocess
from dataclasses import dataclass

import yaml


@dataclass
class FolderListClass:
    git_folder: dict[str, dict[str, str]]
    symlink_data: dict[str, dict[str, str]]
    copy_data: dict[str, dict[str, str]]


def process_yaml(yaml_file):
    """
    讀取 YAML 檔案並將其轉換為 key-value 結構，其中 key 是資料夾路徑，value 是 git 倉庫 URL。

    Args:
      yaml_file: YAML 檔案的路徑。

    Returns:
      一個字典，其中包含 key-value 結構。
    """
    with open(yaml_file, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    folder_list = FolderListClass(git_folder={}, symlink_data={}, copy_data={})

    def traverse(sub_data, path=""):
        """
        遞迴遍歷 YAML 資料並建立 key-value 結構。

        Args:
          sub_data: YAML 資料。
          path: 當前資料夾路徑。
        """
        for key, value in sub_data.items():
            if not isinstance(value, dict):
                print(f"警告：{key} 在 {path} 中的值無效。")
                continue

            if not isinstance(value.get("type"), str) or not isinstance(
                value.get("path"), str
            ):
                new_path = os.path.join(path, key)
                traverse(value, new_path)
                continue

            item_type: str = value["type"]
            item_path: str = value["path"]
            match item_type:
                case "git":
                    folder_list.git_folder.setdefault(path, {})[key] = item_path
                case "symlink":
                    folder_list.symlink_data.setdefault(path, {})[key] = item_path
                case "copy":
                    folder_list.copy_data.setdefault(path, {})[key] = item_path
                case _:
                    print(f"警告：{key} 在 {path} 中的類型無效。")

    traverse(data)
    return folder_list


def create_folders_and_clone(data: FolderListClass):
    """
    在 home 目錄下建立資料夾並從 git 倉庫複製程式碼。

    Args:
      data: 包含 key-value 結構的字典。
    """
    home_dir = os.path.expanduser("~")  # 取得 home 目錄路徑

    for folder_path, git_data in data.git_folder.items():
        full_path = os.path.join(home_dir, folder_path)
        os.makedirs(full_path, exist_ok=True)

        for folder, git_url in git_data.items():
            if not os.path.exists(os.path.join(full_path, folder)):
                subprocess.run(["git", "clone", git_url, folder], cwd=full_path)


if __name__ == "__main__":
    icloud_data = os.getenv("ICLOUD_DATA")
    if not icloud_data:
        print("錯誤：環境變數 ICLOUD_DATA 未設定")
        raise SystemExit(1)
    config_path = os.path.join(icloud_data, "code_folder.yaml")
    yaml_data = process_yaml(config_path)
    # print(yaml_data)  # 除錯用，可取消註解
    create_folders_and_clone(yaml_data)
