{
  "name": "HCPilot iOS",
  "version": "1.0.0",
  "description": "Operating System for Mobile Healthcare Professionals",
  "authors": "HCPilot Team",
  "swift_versions": "5.9",
  "platforms": [
    "ios"
  ],
  "dependencies": [
    "Alamofire": "~> 5.8",
    "Kingfisher": "~> 7.0",
    "SwiftUI-Introspect": "~> 0.5",
    "SwiftData": ">= 15.0"
  ],
  "swift_tools_version": "5.9",
  "target": [
    {
      "name": "HCPilotApp",
      "platform": "ios",
      "sources": [
        "HCPilotApp"
      ],
      "dependencies": [
        {
          "package": "Alamofire"
        },
        {
          "package": "Kingfisher"
        }
      ]
    }
  ]
}
