for (view in jenkins.model.Jenkins.theInstance.getViews()) {
  if (view.name != 'all') {
    Jenkins.instance.deleteView(view)
  }
}