const appVersionName = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.59',
);
const appBuildNumber = String.fromEnvironment(
  'APP_NATIVE_BUILD',
  defaultValue: '95',
);
const appReleaseId = String.fromEnvironment(
  'APP_RELEASE_ID',
  defaultValue: 'development-r74',
);
const appReleaseOrder = int.fromEnvironment(
  'APP_RELEASE_ORDER',
  defaultValue: 74,
);
const appDistribution = String.fromEnvironment(
  'APP_DISTRIBUTION',
  defaultValue: 'development',
);
const appChannel = String.fromEnvironment(
  'APP_CHANNEL',
  defaultValue: 'development',
);
const appVersionLabel = 'Версия $appVersionName ($appBuildNumber)';
