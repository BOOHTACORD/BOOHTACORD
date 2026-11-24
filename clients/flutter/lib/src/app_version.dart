const appVersionName = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.60',
);
const appBuildNumber = String.fromEnvironment(
  'APP_NATIVE_BUILD',
  defaultValue: '96',
);
const appReleaseId = String.fromEnvironment(
  'APP_RELEASE_ID',
  defaultValue: 'development-r75',
);
const appReleaseOrder = int.fromEnvironment(
  'APP_RELEASE_ORDER',
  defaultValue: 75,
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
