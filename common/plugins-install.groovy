import jenkins.model.Jenkins

instance = Jenkins.instance
pm = instance.pluginManager
uc = instance.updateCenter

Set<String> installPlugins = {{JENKINS_PLUGINS}}

def activatePlugin(plugin) {
  plugin.getDependencies().each {
    println("Processing dependency ${it} for ${plugin}")
    activatePlugin(pm.getPlugin(it.shortName))
  }
  if (! plugin.isEnabled()) {
    println("Enabling ${plugin}")
    plugin.enable()
  }
}

// Disabling all plugins first
pm.plugins.each { plugin ->
  println("Disabling ${plugin}")
  plugin.disable()
}

updated = false

// Installing and activating plugins from list
installPlugins.each {
  println("Processing ${it}")
  if (! pm.getPlugin(it)) {
    println("Installing ${it}")
    deployment = uc.getPlugin(it).deploy(true)
    deployment.get()
    updated = true
    println "Installed ${it}"
  }
  println("Activating ${it}")
  activatePlugin(pm.getPlugin(it))
  sleep(400)
}

// Uninstalling unused plugins
pm.plugins.each { plugin ->
  if (! plugin.isEnabled()) {
    println "Uninstalling ${it}"
    plugin.doDoUninstall()
  }
}

