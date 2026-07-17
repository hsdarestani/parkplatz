import hashlib, secrets, uuid
from datetime import datetime, timedelta, timezone
import jwt
from pwdlib import PasswordHash
from app.core.config import settings
passwords=PasswordHash.recommended()
def hash_password(value:str)->str:return passwords.hash(value)
def verify_password(value:str,hashed:str)->bool:return passwords.verify(value,hashed)
def access_token(user_id:uuid.UUID)->str:return jwt.encode({'sub':str(user_id),'exp':datetime.now(timezone.utc)+timedelta(minutes=15),'type':'access'},settings.jwt_secret,algorithm='HS256')
def refresh_token()->str:return secrets.token_urlsafe(48)
def token_hash(value:str)->str:return hashlib.sha256(value.encode()).hexdigest()
def decode(value:str)->uuid.UUID:return uuid.UUID(jwt.decode(value,settings.jwt_secret,algorithms=['HS256'])['sub'])
