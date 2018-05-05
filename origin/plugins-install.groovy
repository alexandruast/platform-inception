import jenkins.model.Jenkins
sleep(10000)

def instance = Jenkins.get()
pm = Jenkins.instance.pluginManager
uc = Jenkins.instance.updateCenter

Set<String> installPlugins = [
  "build-timeout",
  "credentials",
  "git",
  "job-dsl",
  "mask-passwords",
  "matrix-auth",
  "workflow-aggregator",
  "ws-cleanup"
]

def activatePlugin(plugin) {
  if (! plugin.isEnabled()) {
    plugin.enable()
  }
  plugin.getDependencies().each {
    activatePlugin(pm.getPlugin(it.shortName))
  }
}

// Disabling all plugins first
pm.plugins.each { plugin ->
  plugin.disable()
}

updated = false

// Installing and activating plugins from list
installPlugins.each {
  if (! pm.getPlugin(it)) {
    deployment = uc.getPlugin(it).deploy(true)
    deployment.get()
    updated = true
    println "Installed ${it}"
  }
  activatePlugin(pm.getPlugin(it))
  sleep(400)
}

// Uninstalling unused plugins
pm.plugins.each { plugin ->
  if (! plugin.isEnabled()) {
    plugin.doDoUninstall()
    println "Uninstalled ${plugin}"
  }
}

