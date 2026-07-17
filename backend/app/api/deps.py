import uuid
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import decode
from app.db.session import get_session
bearer=HTTPBearer(auto_error=False)
async def current_user(credentials:HTTPAuthorizationCredentials|None=Depends(bearer))->uuid.UUID:
    try:
        if credentials is None: raise ValueError()
        return decode(credentials.credentials)
    except Exception: raise HTTPException(401,detail={'code':'invalid_session','message':'Sitzung ungültig oder abgelaufen.'})
