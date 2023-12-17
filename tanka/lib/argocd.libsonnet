local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local argo_cd = import 'github.com/jsonnet-libs/argo-cd-libsonnet/2.7/main.libsonnet';

local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local tankaVersion = 'v0.20.0';
local helmVersion = 'v3.13.2';
local jsonnetBundlerVersion = 'v0.5.1';
local pluginDir = '/home/argocd/cmp-server/plugins';

local newApp(name, url, path, project='default', env='default', ns='argocd', destination_ns='argocd') =
  argo_cd.argoproj.v1alpha1.application.new(name)
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.withProject(project)
  + argo_cd.argoproj.v1alpha1.application.mixin.metadata.withNamespace(ns)
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.source.withPath(path)
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.source.withTargetRevision('HEAD')
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.source.plugin.withEnvMixin({ name: 'TK_ENV', value: 'default' })
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.destination.withServer('https://kubernetes.default.svc')
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.destination.withNamespace(destination_ns)
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.syncPolicy.automated.withPrune(true)
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.syncPolicy.automated.withSelfHeal(true)
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.syncPolicy.withSyncOptions(['CreateNamespace=true'])
  + argo_cd.argoproj.v1alpha1.application.mixin.spec.source.withRepoURL(url);

local newAppProject(name, ns='argocd') =
  argo_cd.argoproj.v1alpha1.appProject.new(name)
  + argo_cd.argoproj.v1alpha1.appProject.mixin.spec.withDescription('my foo orga')
  + argo_cd.argoproj.v1alpha1.appProject.mixin.spec.withSourceRepos('*')
  + argo_cd.argoproj.v1alpha1.appProject.mixin.spec.withClusterResourceWhitelistMixin({ group: '*', kind: '*' })
  + argo_cd.argoproj.v1alpha1.appProject.mixin.spec.withNamespaceResourceWhitelistMixin({ group: '*', kind: '*' })
  + argo_cd.argoproj.v1alpha1.appProject.mixin.spec.withDestinationsMixin({ namespace: '*', server: '*' })
  + argo_cd.argoproj.v1alpha1.appProject.mixin.metadata.withNamespace(ns);

local newArgoInstance(ns='argocd') = helm.template('argo-cd', '../charts/argo-cd', {
                                       namespace: ns,
                                       values: {
                                         configs: { params: { 'server.insecure': true, 'server.disable.auth': true } },
                                         repoServer: {
                                           extraContainers: [
                                             {
                                               name: 'cmp',
                                               image: 'quay.io/curl/curl',

                                               local jsonnetBundlerCurlCommand = 'curl -Lo %s/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/%s/jb-linux-amd64' % [pluginDir, jsonnetBundlerVersion],
                                               local helmCurlCommand = 'curl -Lo /tmp/helm.tar.gz https://get.helm.sh/helm-%s-linux-amd64.tar.gz' % helmVersion,
                                               local helmUnpackCommand = 'cd /tmp && tar xf /tmp/helm.tar.gz && mv linux-amd64/helm %s' % pluginDir,
                                               local tankaCurlCommand = 'curl -Lo %s/tk https://github.com/grafana/tanka/releases/download/%s/tk-linux-amd64' % [pluginDir, tankaVersion],
                                               local chmodCommands = 'chmod +x %s/jb && chmod +x %s/tk && chmod +x %s/helm' % [pluginDir, pluginDir, pluginDir],

                                               command: [
                                                 'sh',
                                                 '-c',
                                                 '%s && %s && %s && %s && %s && /var/run/argocd/argocd-cmp-server' % [jsonnetBundlerCurlCommand, tankaCurlCommand, helmCurlCommand, helmUnpackCommand, chmodCommands],
                                               ],
                                               securityContext: {
                                                 runAsNonRoot: true,
                                                 runAsUser: 999,
                                               },
                                               volumeMounts: [
                                                 {
                                                   mountPath: '/var/run/argocd',
                                                   name: 'var-files',
                                                 },
                                                 {
                                                   mountPath: pluginDir,
                                                   name: 'plugins',
                                                 },
                                                 {
                                                   mountPath: '/home/argocd/cmp-server/config/plugin.yaml',
                                                   subPath: 'plugin.yaml',
                                                   name: 'cmp-plugin',
                                                 },
                                               ],
                                             },
                                           ],
                                           volumes: [
                                             {
                                               configMap: {
                                                 name: 'cmp-plugin',
                                               },
                                               name: 'cmp-plugin',
                                             },
                                             {
                                               emptyDir: {},
                                               name: 'cmp-tmp',
                                             },
                                           ],
                                         },
                                       },
                                     }) +
                                     {
                                       local data = {
                                         'plugin.yaml': |||
                                           %s
                                         ||| % std.manifestYamlDoc({
                                           apiVersion: 'argoproj.io/v1alpha1',
                                           kind: 'ConfigManagementPlugin',
                                           metadata: {
                                             name: 'tanka',
                                             namespace: ns,
                                           },
                                           spec: {
                                             version: tankaVersion,
                                             init: {
                                               command: [
                                                 'sh',
                                                 '-c',
                                                 '%s/jb install' % pluginDir,
                                               ],
                                             },
                                             generate: {
                                               command: [
                                                 'sh',
                                                 '-c',
                                                 'TANKA_HELM_PATH=%s/helm %s/tk show environments/${ARGOCD_ENV_TK_ENV} --dangerous-allow-redirect' % [pluginDir, pluginDir],
                                               ],
                                             },
                                             discover: {
                                               fileName: 'jsonnetfile.json',
                                             },
                                           },
                                         }),
                                       },
                                       cmpConfig: k.core.v1.configMap.new('cmp-plugin', data) + k.core.v1.configMap.mixin.metadata.withNamespace(ns),
                                     };

{
  newArgoInstance:: newArgoInstance,
  newAppProject:: newAppProject,
  newApp:: newApp,
}
