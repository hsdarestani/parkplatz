import secrets
from datetime import datetime,timedelta,timezone
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import access_token,hash_password,refresh_token,token_hash,verify_password
from app.models import RefreshToken,User
class AuthService:
 @staticmethod
 async def register(db:AsyncSession,email:str,password:str,name:str):
  normalized=email.strip().lower()
  if await db.scalar(select(User).where(User.email==normalized)): raise HTTPException(409,detail={'code':'email_unavailable','message':'Registrierung nicht möglich.'})
  user=User(email=normalized,password_hash=hash_password(password),display_name=name);db.add(user);await db.flush();return await AuthService._tokens(db,user)
 @staticmethod
 async def login(db:AsyncSession,email:str,password:str):
  user=await db.scalar(select(User).where(User.email==email.strip().lower()))
  if not user or not verify_password(password,user.password_hash): raise HTTPException(401,detail={'code':'invalid_credentials','message':'E-Mail oder Passwort ist ungültig.'})
  return await AuthService._tokens(db,user)
 @staticmethod
 async def _tokens(db,user):
  raw=refresh_token();db.add(RefreshToken(user_id=user.id,token_hash=token_hash(raw),expires_at=datetime.now(timezone.utc)+timedelta(days=30)));await db.commit();return {'access_token':access_token(user.id),'refresh_token':raw,'token_type':'bearer','user':{'id':str(user.id),'email':user.email,'display_name':user.display_name}}
