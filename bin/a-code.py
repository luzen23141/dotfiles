import os
import shutil
import subprocess
import sys
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
    if not os.path.isfile(yaml_file):
        print(f"錯誤：找不到設定檔：{yaml_file}")
        raise SystemExit(1)

    with open(yaml_file, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if data is None:
        print(f"錯誤：設定檔為空：{yaml_file}")
        raise SystemExit(1)
    if not isinstance(data, dict):
        print(f"錯誤：設定檔根節點必須是物件（mapping）：{yaml_file}")
        raise SystemExit(1)

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


def _dest_path(home_dir: str, folder_path: str, name: str) -> str:
    return os.path.join(home_dir, folder_path, name)


def _ensure_parent(dest: str) -> None:
    os.makedirs(os.path.dirname(dest), exist_ok=True)


def create_folders_and_clone(data: FolderListClass) -> int:
    """
    在 home 目錄下建立資料夾，並依設定 clone / symlink / copy。

    Returns:
      錯誤次數（0 表示全部成功或僅略過）。
    """
    home_dir = os.path.expanduser("~")
    errors = 0

    for folder_path, git_data in data.git_folder.items():
        full_path = os.path.join(home_dir, folder_path)
        os.makedirs(full_path, exist_ok=True)

        for folder, git_url in git_data.items():
            dest = os.path.join(full_path, folder)
            if os.path.lexists(dest):
                print(f"略過 git（已存在）：{dest}")
                continue
            print(f"clone：{git_url} -> {dest}")
            try:
                subprocess.run(
                    ["git", "clone", git_url, folder], cwd=full_path, check=True
                )
            except subprocess.CalledProcessError:
                print(f"錯誤：git clone 失敗：{git_url}")
                errors += 1

    for folder_path, link_data in data.symlink_data.items():
        for name, source in link_data.items():
            dest = _dest_path(home_dir, folder_path, name)
            source_path = os.path.expanduser(source)
            if os.path.lexists(dest):
                print(f"略過 symlink（已存在）：{dest}")
                continue
            if not os.path.exists(source_path):
                print(f"錯誤：symlink 來源不存在：{source_path}")
                errors += 1
                continue
            _ensure_parent(dest)
            print(f"symlink：{dest} -> {source_path}")
            try:
                os.symlink(source_path, dest)
            except OSError as e:
                print(f"錯誤：建立 symlink 失敗：{dest} ({e})")
                errors += 1

    for folder_path, copy_entries in data.copy_data.items():
        for name, source in copy_entries.items():
            dest = _dest_path(home_dir, folder_path, name)
            source_path = os.path.expanduser(source)
            if os.path.lexists(dest):
                print(f"略過 copy（已存在）：{dest}")
                continue
            if not os.path.exists(source_path):
                print(f"錯誤：copy 來源不存在：{source_path}")
                errors += 1
                continue
            _ensure_parent(dest)
            print(f"copy：{source_path} -> {dest}")
            try:
                if os.path.isdir(source_path):
                    shutil.copytree(source_path, dest)
                else:
                    shutil.copy2(source_path, dest)
            except OSError as e:
                print(f"錯誤：copy 失敗：{dest} ({e})")
                errors += 1

    return errors


if __name__ == "__main__":
    icloud_data = os.getenv("ICLOUD_DATA")
    if not icloud_data:
        print("錯誤：環境變數 ICLOUD_DATA 未設定")
        raise SystemExit(1)
    config_path = os.path.join(icloud_data, "code_folder.yaml")
    yaml_data = process_yaml(config_path)
    # print(yaml_data)  # 除錯用，可取消註解
    error_count = create_folders_and_clone(yaml_data)
    if error_count:
        print(f"完成，但有 {error_count} 個錯誤")
        sys.exit(1)
