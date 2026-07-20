import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';

final searchProvider =
    StateNotifierProvider<SearchController, SearchQuery>((ref) {
  return SearchController();
});

class SearchController extends StateNotifier<SearchQuery> {
  SearchController() : super(_initial());

  static SearchQuery _initial() {
    final now = DateTime.now();
    final rounded = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour + 1,
    );
    return SearchQuery(
      start: rounded,
      end: rounded.add(const Duration(hours: 2)),
    );
  }

  void destination(Destination value) {
    state = state.copyWith(destination: value);
  }

  void vehicle(Vehicle value) {
    state = state.copyWith(vehicle: value);
  }

  void start(DateTime value) {
    final duration = state.end.difference(state.start);
    state = state.copyWith(
      start: value,
      end: value.add(
        duration.inMinutes <= 0 ? const Duration(hours: 1) : duration,
      ),
    );
  }

  void duration(int hours) {
    final safeHours = hours.clamp(1, 24 * 30);
    state = state.copyWith(end: state.start.add(Duration(hours: safeHours)));
  }

  void durationValue(Duration value) {
    final minutes = value.inMinutes.clamp(60, 24 * 30 * 60);
    state = state.copyWith(
      end: state.start.add(Duration(minutes: minutes)),
    );
  }

  void range(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return;
    final maximum = start.add(const Duration(days: 30));
    state = state.copyWith(
      start: start,
      end: end.isAfter(maximum) ? maximum : end,
    );
  }

  void toggle(String filter) {
    final filters = {...state.filters};
    filters.contains(filter) ? filters.remove(filter) : filters.add(filter);
    state = state.copyWith(filters: filters);
  }

  void exclusiveAccessFilter(String filter) {
    final filters = {...state.filters}
      ..remove('garage')
      ..remove('indoor')
      ..remove('outdoor');
    if (!state.filters.contains(filter)) filters.add(filter);
    state = state.copyWith(filters: filters);
  }

  void sort(String value) {
    state = state.copyWith(sort: value);
  }

  void reset() {
    state = _initial();
  }
}
