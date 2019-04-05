workflow "Continuous Integration" {
  on = "push"
  resolves = ["Check Formatting", "Check Credo"]
}

action "Get Deps" {
  uses = "jclem/action-mix/deps.get@v1.3.3"
}

action "Check Formatting" {
  uses = "jclem/action-mix@v1.3.3"
  needs = "Get Deps"
  args = "format --check-formatted"
}

action "Check Credo" {
  uses = "jclem/action-mix@v1.3.3"
  needs = "Get Deps"
  args = "credo"
}
