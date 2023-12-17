local argo = import 'argocd.libsonnet';
local config = import 'config.jsonnet';
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

(config) + {
  local base = self,
  argo_ns: k.core.v1.namespace.new(base._config.namespace),
  argo: argo.newArgoInstance(ns=base._config.namespace),
  foo_project: argo.newAppProject('foo', ns=base._config.namespace),
  argo_app: argo.newApp('bar', 'https://github.com/dadav/argo-tanka.git', 'tanka', env='default', ns=base._config.namespace, destination_ns=base._config.namespace),
  rocketchat_app: argo.newApp('baz', 'https://github.com/dadav/tanka-test.git', '.', project='foo', env='default', ns=base._config.namespace, destination_ns='foo'),
}
