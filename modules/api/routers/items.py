"""
アイテムCRUDエンドポイント
"""

from datetime import datetime
from typing import List, Dict, Any
from fastapi import APIRouter, HTTPException, status
from ..models.schemas import Item, ItemCreate, ItemUpdate, ItemList, ErrorResponse

router = APIRouter()

# インメモリストレージ（実際のプロジェクトではデータベースを使用）
items_storage: Dict[int, Dict[str, Any]] = {}
next_id = 1


@router.get("/api/items", response_model=ItemList, tags=["Items"])
async def get_items() -> ItemList:
    """
    アイテム一覧取得
    """
    items = []
    for item_id, item_data in items_storage.items():
        items.append(Item(
            id=item_id,
            name=item_data["name"],
            description=item_data["description"],
            created_at=item_data["created_at"],
            updated_at=item_data.get("updated_at")
        ))
    
    return ItemList(items=items, total=len(items))


@router.get("/api/items/{item_id}", response_model=Item, tags=["Items"])
async def get_item(item_id: int) -> Item:
    """
    アイテム詳細取得
    """
    if item_id not in items_storage:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"アイテムID {item_id} が見つかりません"
        )
    
    item_data = items_storage[item_id]
    return Item(
        id=item_id,
        name=item_data["name"],
        description=item_data["description"],
        created_at=item_data["created_at"],
        updated_at=item_data.get("updated_at")
    )


@router.post("/api/items", response_model=Item, status_code=status.HTTP_201_CREATED, tags=["Items"])
async def create_item(item: ItemCreate) -> Item:
    """
    アイテム作成
    """
    global next_id
    
    current_time = datetime.utcnow()
    item_data = {
        "name": item.name,
        "description": item.description,
        "created_at": current_time,
        "updated_at": None
    }
    
    items_storage[next_id] = item_data
    created_item = Item(
        id=next_id,
        name=item_data["name"],
        description=item_data["description"],
        created_at=item_data["created_at"],
        updated_at=item_data["updated_at"]
    )
    
    next_id += 1
    return created_item


@router.put("/api/items/{item_id}", response_model=Item, tags=["Items"])
async def update_item(item_id: int, item: ItemUpdate) -> Item:
    """
    アイテム更新
    """
    if item_id not in items_storage:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"アイテムID {item_id} が見つかりません"
        )
    
    item_data = items_storage[item_id]
    current_time = datetime.utcnow()
    
    # 更新されたフィールドのみを更新
    if item.name is not None:
        item_data["name"] = item.name
    if item.description is not None:
        item_data["description"] = item.description
    
    item_data["updated_at"] = current_time
    
    return Item(
        id=item_id,
        name=item_data["name"],
        description=item_data["description"],
        created_at=item_data["created_at"],
        updated_at=item_data["updated_at"]
    )


@router.delete("/api/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Items"])
async def delete_item(item_id: int):
    """
    アイテム削除
    """
    if item_id not in items_storage:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"アイテムID {item_id} が見つかりません"
        )
    
    del items_storage[item_id]