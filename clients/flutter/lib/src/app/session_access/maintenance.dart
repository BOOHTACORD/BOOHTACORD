import '../composition/owners.dart';

mixin AppMaintenanceAccess on AppOwners {
  bool get maintenanceActive => maintenance.active;
  bool get maintenanceKnown => maintenance.known;

  set maintenanceActive(bool value) => maintenance.active = value;
}
