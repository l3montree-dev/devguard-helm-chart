{
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/k3s.version/"],
      "matchStrings": ["(?<currentValue>\\S+)"],
      "depNameTemplate": "k3s",
      "versioningTemplate": "semver-coerced",
      "datasourceTemplate": "custom.k3s"
    }
  ],
  "customDatasources": {
    "k3s": {
      "defaultRegistryUrlTemplate": "https://update.k3s.io/v1-release/channels?<debName>",
      "transformTemplates": [
        "{\"releases\":[{\"version\": $$.(data[id = 'stable'].latest),\"sourceUrl\":\"https://github.com/k3s-io/k3s\",\"changelogUrl\":$join([\"https://github.com/k3s-io/k3s/releases/tag/\",data[id = 'stable'].latest])}],\"sourceUrl\": \"https://github.com/k3s-io/k3s\",\"homepage\": \"https://k3s.io/\"}"
      ]
    }
  }
}

