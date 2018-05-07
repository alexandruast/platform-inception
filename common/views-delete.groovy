for (view in jenkins.model.Jenkins.theInstance.getViews()) {
  if (view.name.toLowerCase() != 'all') {
    Jenkins.instance.deleteView(view)
  }
}