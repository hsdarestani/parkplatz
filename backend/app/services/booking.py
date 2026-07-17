import math,secrets,uuid
from datetime import datetime,timezone
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import AvailabilityBlock,Booking,BookingEvent,BookingStatus,ParkingSpace,Vehicle
class BookingService:
 @staticmethod
 async def create(db:AsyncSession,user_id:uuid.UUID,data):
  previous=await db.scalar(select(Booking).where(Booking.user_id==user_id,Booking.idempotency_key==data.idempotency_key))
  if previous:return previous
  if data.end_at<=data.start_at or data.start_at<=datetime.now(timezone.utc):raise HTTPException(422,detail={'code':'invalid_time','message':'Bitte wähle einen gültigen zukünftigen Zeitraum.'})
  hours=(data.end_at-data.start_at).total_seconds()/3600
  if hours<1 or hours>24:raise HTTPException(422,detail={'code':'invalid_duration','message':'Buchungen sind zwischen 1 und 24 Stunden möglich.'})
  space=await db.scalar(select(ParkingSpace).where(ParkingSpace.id==data.parking_space_id).with_for_update())
  vehicle=await db.scalar(select(Vehicle).where(Vehicle.id==data.vehicle_id,Vehicle.user_id==user_id))
  if not space or space.status!='active' or not vehicle:raise HTTPException(404,detail={'code':'not_found','message':'Stellplatz oder Fahrzeug nicht gefunden.'})
  if any([vehicle.height_m>space.max_height_m,vehicle.width_m>space.max_width_m,vehicle.length_m>space.max_length_m]):raise HTTPException(422,detail={'code':'vehicle_too_large','message':'Das ausgewählte Fahrzeug passt nicht.'})
  overlap=await db.scalar(select(Booking.id).where(Booking.parking_space_id==space.id,Booking.status.in_([BookingStatus.pending,BookingStatus.confirmed]),Booking.start_at<data.end_at,Booking.end_at>data.start_at))
  blocked=await db.scalar(select(AvailabilityBlock.id).where(AvailabilityBlock.parking_space_id==space.id,AvailabilityBlock.start_at<data.end_at,AvailabilityBlock.end_at>data.start_at))
  if overlap or blocked:raise HTTPException(409,detail={'code':'booking_conflict','message':'Dieser Zeitraum wurde gerade gebucht. Bitte wähle eine andere Zeit.'})
  booking=Booking(public_reference=f'FR-{secrets.token_hex(3).upper()}',user_id=user_id,parking_space_id=space.id,vehicle_id=vehicle.id,start_at=data.start_at,end_at=data.end_at,status=BookingStatus.confirmed,hourly_price_cents_snapshot=space.hourly_price_cents,total_price_cents=math.ceil(hours)*space.hourly_price_cents,currency=space.currency,access_code=f'{secrets.randbelow(1000000):06d}',parking_pass_token=secrets.token_urlsafe(32),idempotency_key=data.idempotency_key,confirmed_at=datetime.now(timezone.utc));db.add(booking);await db.flush();db.add(BookingEvent(booking_id=booking.id,event_type='confirmed',event_metadata={'payment':'beta_no_payment'}));await db.commit();return booking
