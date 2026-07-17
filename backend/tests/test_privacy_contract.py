from app.api.routes import public_space
class Space:
 id='00000000-0000-0000-0000-000000000001';slug='demo';title='Demo';district='Gallus';landmark='Messe';latitude=50.1;longitude=8.6;hourly_price_cents=300;currency='EUR';max_height_m=2.1;max_width_m=2.2;max_length_m=5.0;access_type='Tor';is_covered=True;has_ev_charging=False;is_accessible=True;is_instant_bookable=True;is_verified=True;rating=4.8;review_count=10;exact_address='PRIVATE';entrance_instructions='PRIVATE'
def test_public_contract_excludes_protected_fields():
 result=public_space(Space())
 assert 'exact_address' not in result
 assert 'entrance_instructions' not in result
 assert 'access_code' not in result
 assert 'parking_pass_token' not in result
