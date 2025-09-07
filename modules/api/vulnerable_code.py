"""
SAST検出テスト用の脆弱なコード
本番環境では絶対に使用しないこと
"""
import os
import subprocess
import pickle
import hashlib

# CRITICAL: SQLインジェクション脆弱性
def unsafe_sql_query(user_input):
    """SQLインジェクション脆弱性 - CRITICAL"""
    query = f"SELECT * FROM users WHERE name = '{user_input}'"
    return query

# CRITICAL: コマンドインジェクション脆弱性
def unsafe_command_execution(user_input):
    """コマンドインジェクション脆弱性 - CRITICAL"""
    os.system(f"echo {user_input}")
    subprocess.call(f"ls {user_input}", shell=True)

# CRITICAL: デシリアライゼーション脆弱性
def unsafe_pickle_load(data):
    """Pickleデシリアライゼーション脆弱性 - CRITICAL"""
    return pickle.loads(data)

# CRITICAL: ハードコードされた認証情報
API_KEY = "sk-1234567890abcdef"  # CRITICAL: ハードコードされたAPIキー
DATABASE_PASSWORD = "admin123"   # CRITICAL: ハードコードされたパスワード
SECRET_TOKEN = "super_secret_token_12345"

# CRITICAL: 弱い暗号化
def weak_hash(password):
    """弱いハッシュ関数 - CRITICAL"""
    return hashlib.md5(password.encode()).hexdigest()

# CRITICAL: パストラバーサル脆弱性
def unsafe_file_read(filename):
    """パストラバーサル脆弱性 - CRITICAL"""
    with open(f"/app/files/{filename}", 'r') as f:
        return f.read()

# CRITICAL: eval()の使用
def unsafe_eval(user_code):
    """eval()による任意コード実行 - CRITICAL"""
    return eval(user_code)

# CRITICAL: exec()の使用
def unsafe_exec(user_code):
    """exec()による任意コード実行 - CRITICAL"""
    exec(user_code)

# CRITICAL: 安全でないランダム生成
import random
def weak_token_generation():
    """弱いトークン生成 - CRITICAL"""
    return str(random.randint(1000, 9999))

# CRITICAL: XXE脆弱性
import xml.etree.ElementTree as ET
def unsafe_xml_parse(xml_data):
    """XXE脆弱性 - CRITICAL"""
    return ET.fromstring(xml_data)
