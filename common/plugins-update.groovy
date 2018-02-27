import jenkins.model.Jenkins

pm = Jenkins.instance.pluginManager
uc = Jenkins.instance.updateCenter
updated = false
pm.plugins.each { plugin ->
  new_version = uc.getPlugin(plugin.shortName).version
  if (new_version != plugin.version) {
    println "Updating ${plugin.shortName} to ${new_version}"
    update = uc.getPlugin(plugin.shortName).deploy(true)
    update.get()
    updated = true
  }
}

