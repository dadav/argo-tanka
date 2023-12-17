local argo = import 'argocd.libsonnet';
local config = import 'config.jsonnet';
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

(config) + {
  local base = self,
  instance: argo.newArgoInstance(ns=base._config.namespace),
  project: argo.newAppProject('foo', ns=base._config.namespace),
  app: argo.newApp('bar', 'https://github.com/dadav/argo-tanka.git', 'tanka', env='default', ns=base._config.namespace, destination_ns=base._config.namespace),
  another_app: argo.newApp('baz', 'https://github.com/dadav/tanka-test.git', '.', env='default', ns=base._config.namespace, destination_ns='foo'),
}
