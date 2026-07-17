import uuid
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field
class Register(BaseModel): display_name:str=Field(min_length=2,max_length=100); email:EmailStr; password:str=Field(min_length=8,max_length=128)
class Login(BaseModel): email:EmailStr; password:str
class Refresh(BaseModel): refresh_token:str
class VehicleIn(BaseModel): name:str; plate:str; height_m:float; width_m:float; length_m:float; is_default:bool=False
class BookingIn(BaseModel): parking_space_id:uuid.UUID; vehicle_id:uuid.UUID; start_at:datetime; end_at:datetime; idempotency_key:str=Field(min_length=8,max_length=100)
class CancelIn(BaseModel): reason:str='Vom Nutzer storniert'
