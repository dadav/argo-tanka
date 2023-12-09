local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local tankaVersion = 'v0.20.0';
local helmVersion = 'v3.13.2';
local jsonnetBundlerVersion = 'v0.5.1';
local pluginDir = '/home/argocd/cmp-server/plugins';

local newApp(name, url, path, env='default', ns='argocd') = {
  apiVersion: 'argoproj.io/v1alpha1',
  kind: 'Application',
  metadata: {
    name: name,
    namespace: ns,
  },
  spec: {
    project: 'default',
    source: {
      repoURL: url,
      path: path,
      targetRevision: 'HEAD',
      plugin: {
        env: [
          {
            name: 'TK_ENV',  // prefixed in the Plugin with `ARGOCD_ENV_`
            value: 'default',
          },
        ],
      },
    },
    destination: {
      server: 'https://kubernetes.default.svc',
    },
    syncPolicy: {
      automated: {
        prune: true,
        selfHeal: true,
      },
    },
  },
};

local newAppProject(name, ns='argocd') = {
  apiVersion: 'argoproj.io/v1alpha1',
  kind: 'AppProject',
  metadata: {
    name: name,
    namespace: ns,
    finalizers: [
      'resources-finalizer.argocd.argoproj.io',
    ],
  },
  spec: {
    description: 'MyOrg Default AppProject',
    sourceRepos: [
      '*',
    ],
    clusterResourceWhitelist: [
      {
        group: '*',
        kind: '*',
      },
    ],
    destinations: [
      {
        namespace: '*',
        server: '*',
      },
    ],
  },
};

local newArgoInstance(ns='argocd') = helm.template('argo-cd', '../../charts/argo-cd', {
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
}) + { argoCdPlugin: {
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'cmp-plugin',
    namespace: ns,
  },
  data: {
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
          fileName: '*',
        },
      },
    }),
  },
} };

{
  newArgoInstance:: newArgoInstance,
  newAppProject:: newAppProject,
  newApp:: newApp,
}
