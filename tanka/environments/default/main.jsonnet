local argo = import 'argocd.libsonnet';
local config = import 'config.jsonnet';
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

(config) + {
  local base = self,
  namespace: k.core.v1.namespace.new(base._config.namespace),
  instance: argo.newArgoInstance(ns=base._config.namespace),
  project: argo.newAppProject('foo', ns=base._config.namespace),
  app: argo.newApp('bar', 'https://github.com/dadav/argo-tanka.git', 'tanka', env='default', ns=base._config.namespace),
}
