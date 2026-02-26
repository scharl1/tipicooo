class DateFormatIt {
  const DateFormatIt._();

  static String dateTimeFromIso(String iso) {
    final raw = iso.trim();
    if (raw.isEmpty) return "";
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return dateTime(dt);
  }

  static String dateTime(DateTime dt) {
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return "$dd/$mm/$yyyy $hh:$min";
  }
}
