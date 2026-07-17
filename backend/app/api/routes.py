import uuid
from datetime import datetime,timezone
from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import select,text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import current_user
from app.core.config import settings
from app.core.security import token_hash
from app.db.session import get_session
from app.models import Booking,BookingEvent,BookingStatus,ParkingSpace,RefreshToken,User,Vehicle
from app.schemas.api import BookingIn,CancelIn,Login,Refresh,Register,VehicleIn
from app.services.auth import AuthService
from app.services.booking import BookingService
router=APIRouter(prefix='/api')
def public_space(p):return {'id':str(p.id),'slug':p.slug,'title':p.title,'district':p.district,'landmark':p.landmark,'latitude':float(p.latitude),'longitude':float(p.longitude),'hourly_price_cents':p.hourly_price_cents,'currency':p.currency,'max_height_m':float(p.max_height_m),'max_width_m':float(p.max_width_m),'max_length_m':float(p.max_length_m),'access_type':p.access_type,'is_covered':p.is_covered,'has_ev_charging':p.has_ev_charging,'is_accessible':p.is_accessible,'is_instant_bookable':p.is_instant_bookable,'is_verified':p.is_verified,'rating':float(p.rating),'review_count':p.review_count}
def booking_out(b,p=None,protected=False):
 d={'id':str(b.id),'public_reference':b.public_reference,'parking_space_id':str(b.parking_space_id),'vehicle_id':str(b.vehicle_id),'start_at':b.start_at,'end_at':b.end_at,'status':b.status,'hourly_price_cents_snapshot':b.hourly_price_cents_snapshot,'total_price_cents':b.total_price_cents,'currency':b.currency,'cancelled_at':b.cancelled_at}
 if protected and b.status==BookingStatus.confirmed:d.update(exact_address=p.exact_address,entrance_instructions=p.entrance_instructions,access_code=b.access_code,parking_pass_token=b.parking_pass_token)
 return d
@router.get('/health')
async def health(db:AsyncSession=Depends(get_session)):
 try:await db.execute(text('select 1'));database='connected'
 except Exception:database='unavailable'
 return {'status':'ok' if database=='connected' else 'degraded','application':'FREIRAUM API','database':database,'environment':settings.environment,'version':settings.version}
@router.post('/auth/register',status_code=201)
async def register(data:Register,db=Depends(get_session)):return await AuthService.register(db,str(data.email),data.password,data.display_name)
@router.post('/auth/login')
async def login(data:Login,db=Depends(get_session)):return await AuthService.login(db,str(data.email),data.password)
@router.post('/auth/refresh')
async def refresh(data:Refresh,db=Depends(get_session)):
 token=await db.scalar(select(RefreshToken).where(RefreshToken.token_hash==token_hash(data.refresh_token),RefreshToken.revoked_at.is_(None)))
 if not token or token.expires_at<datetime.now(timezone.utc):raise HTTPException(401,detail={'code':'invalid_refresh','message':'Sitzung abgelaufen.'})
 token.revoked_at=datetime.now(timezone.utc);user=await db.get(User,token.user_id);return await AuthService._tokens(db,user)
@router.post('/auth/logout',status_code=204)
async def logout(data:Refresh,db=Depends(get_session)):
 token=await db.scalar(select(RefreshToken).where(RefreshToken.token_hash==token_hash(data.refresh_token))); 
 if token:token.revoked_at=datetime.now(timezone.utc);await db.commit()
@router.get('/auth/me')
async def me(uid=Depends(current_user),db=Depends(get_session)):
 u=await db.get(User,uid);return {'id':str(u.id),'email':u.email,'display_name':u.display_name}
@router.get('/parking-spaces')
async def spaces(covered:bool|None=None,ev:bool|None=None,accessible:bool|None=None,instant:bool|None=None,db=Depends(get_session)):
 q=select(ParkingSpace).where(ParkingSpace.status=='active')
 for value,column in [(covered,ParkingSpace.is_covered),(ev,ParkingSpace.has_ev_charging),(accessible,ParkingSpace.is_accessible),(instant,ParkingSpace.is_instant_bookable)]:
  if value is not None:q=q.where(column==value)
 return [public_space(p) for p in (await db.scalars(q)).all()]
@router.get('/parking-spaces/{space_id}')
async def space(space_id:uuid.UUID,db=Depends(get_session)):
 p=await db.get(ParkingSpace,space_id)
 if not p:raise HTTPException(404)
 return public_space(p)
@router.get('/parking-spaces/{space_id}/availability')
async def availability(space_id:uuid.UUID,start_at:datetime,end_at:datetime,db=Depends(get_session)):
 overlap=await db.scalar(select(Booking.id).where(Booking.parking_space_id==space_id,Booking.status==BookingStatus.confirmed,Booking.start_at<end_at,Booking.end_at>start_at));return {'available':not bool(overlap),'start_at':start_at,'end_at':end_at}
@router.get('/vehicles')
async def vehicles(uid=Depends(current_user),db=Depends(get_session)):return (await db.scalars(select(Vehicle).where(Vehicle.user_id==uid))).all()
@router.post('/vehicles',status_code=201)
async def add_vehicle(data:VehicleIn,uid=Depends(current_user),db=Depends(get_session)):
 v=Vehicle(user_id=uid,**data.model_dump(),plate=data.plate.upper().strip());db.add(v);await db.commit();await db.refresh(v);return v
@router.patch('/vehicles/{vehicle_id}')
async def patch_vehicle(vehicle_id:uuid.UUID,data:VehicleIn,uid=Depends(current_user),db=Depends(get_session)):
 v=await db.scalar(select(Vehicle).where(Vehicle.id==vehicle_id,Vehicle.user_id==uid))
 if not v:raise HTTPException(404)
 for key,value in data.model_dump().items():setattr(v,key,value)
 await db.commit();return v
@router.delete('/vehicles/{vehicle_id}',status_code=204)
async def delete_vehicle(vehicle_id:uuid.UUID,uid=Depends(current_user),db=Depends(get_session)):
 v=await db.scalar(select(Vehicle).where(Vehicle.id==vehicle_id,Vehicle.user_id==uid))
 if not v:raise HTTPException(404)
 await db.delete(v);await db.commit()
@router.post('/bookings',status_code=201)
async def create_booking(data:BookingIn,uid=Depends(current_user),db=Depends(get_session)):return booking_out(await BookingService.create(db,uid,data))
@router.get('/bookings')
async def bookings(uid=Depends(current_user),db=Depends(get_session)):return [booking_out(b) for b in (await db.scalars(select(Booking).where(Booking.user_id==uid).order_by(Booking.start_at))).all()]
@router.get('/bookings/{booking_id}')
async def booking(booking_id:uuid.UUID,uid=Depends(current_user),db=Depends(get_session)):
 b=await db.scalar(select(Booking).where(Booking.id==booking_id,Booking.user_id==uid))
 if not b:raise HTTPException(404)
 return booking_out(b,await db.get(ParkingSpace,b.parking_space_id),True)
@router.post('/bookings/{booking_id}/cancel')
async def cancel(booking_id:uuid.UUID,data:CancelIn,uid=Depends(current_user),db=Depends(get_session)):
 b=await db.scalar(select(Booking).where(Booking.id==booking_id,Booking.user_id==uid).with_for_update())
 if not b:raise HTTPException(404)
 if b.status in [BookingStatus.cancelled,BookingStatus.completed]:raise HTTPException(409,detail={'code':'not_cancellable','message':'Diese Buchung kann nicht storniert werden.'})
 b.status=BookingStatus.cancelled;b.cancelled_at=datetime.now(timezone.utc);b.cancellation_reason=data.reason;b.access_code='';b.parking_pass_token='';db.add(BookingEvent(booking_id=b.id,event_type='cancelled',event_metadata={'reason':data.reason}));await db.commit();return booking_out(b)
