import asyncio
from datetime import time
from sqlalchemy import select
from app.db.session import Session
from app.models import AvailabilityRule,ParkingSpace
SPACES=[('europagarten','Tiefgarage am Europagarten','Gallus','Europagarten',50.106,8.635,320),('messeost','Privatstellplatz nahe Messe Tor Ost','Westend','Messe Tor Ost',50.113,8.648,270),('hbf-sued','Innenhof am Hauptbahnhof Süd','Gutleutviertel','Hauptbahnhof',50.104,8.663,290),('bockenheim','Praxisstellplatz Bockenheim','Bockenheim','Bockenheimer Warte',50.120,8.646,240),('westend-hotel','Hotelgarage am Westend','Westend','Alte Oper',50.116,8.668,410),('uniklinik','Stellplatz nahe Universitätsklinikum','Niederrad','Universitätsklinikum',50.096,8.659,220),('gallus-office','Büroparkplatz Gallus','Gallus','Skyline Plaza',50.109,8.650,280),('alteoper-hof','Innenhof nahe Alte Oper','Innenstadt','Alte Oper',50.116,8.672,380),('hauptwache','Garage an der Hauptwache','Innenstadt','Hauptwache',50.114,8.679,430),('nordend','Privatplatz Nordend','Nordend','Günthersburgpark',50.126,8.696,210),('roemer','Altstadtgarage am Römer','Altstadt','Römer',50.110,8.682,450),('osthafen','Bürostellplatz Osthafen','Ostend','Osthafen',50.112,8.720,260)]
async def seed():
 async with Session() as db:
  for slug,title,district,landmark,lat,lng,price in SPACES:
   if await db.scalar(select(ParkingSpace).where(ParkingSpace.slug==slug)):continue
   p=ParkingSpace(slug=slug,title=title,district=district,landmark=landmark,latitude=lat,longitude=lng,exact_address=f'Geschützte fiktive Adresse {slug}',entrance_instructions='Zufahrt und Stellplatznummer stehen ausschließlich in der bestätigten Buchung.',hourly_price_cents=price,currency='EUR',max_height_m=2.1,max_width_m=2.3,max_length_m=5.2,access_type='Schranke',is_covered=True,has_ev_charging=False,is_accessible=True,is_instant_bookable=True,is_verified=True,rating=4.7,review_count=42,status='active');db.add(p);await db.flush()
   for weekday in range(7):db.add(AvailabilityRule(parking_space_id=p.id,weekday=weekday,start_time=time(0),end_time=time(23,59),active=True))
  await db.commit()
if __name__=='__main__':asyncio.run(seed())
