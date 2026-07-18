import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';

class PaymentAwareBookingRepository implements BookingRepository {
  const PaymentAwareBookingRepository(this.delegate, this.api);

  final BookingRepository delegate;
  final ApiClient api;

  @override
  Future<List<BookingRecord>> all() => delegate.all();

  @override
  Future<BookingRecord?> detail(String id) => delegate.detail(id);

  @override
  Future<BookingRecord> create(BookingRecord booking) =>
      delegate.create(booking);

  @override
  Future<void> cancel(String id) async {
    await api.post(
      '/payments/bookings/$id/cancel',
      body: {'reason': 'Vom Nutzer storniert'},
    );
  }
}
