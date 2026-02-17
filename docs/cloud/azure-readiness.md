# Azure Readiness Notes

## Preferred Services

| Capability | Azure Service | Notes |
|------------|--------------|-------|
| Entitlement validation API | Azure App Service (Linux) | Hosts StoreKit receipt validator once backend allowed. |
| Telemetry + achievements | Azure Functions + Cosmos DB | Serverless ingestion for Legit Mode heartbeats and achievement evaluation. |
| Multiplayer signaling | Azure Kubernetes Service (AKS) + Azure Communication Services TURN | Provides WebRTC signaling REST + TURN relays. |
| Messaging | Azure Service Bus | Propagates entitlement revocations + leaderboard refresh events. |

## Environment Strategy

- **Environments**: `dev` (TestFlight), `staging`, `prod`. AppHost will target `dev` mock endpoints until cloud services exist.
- **Identity**: Managed identity for App Service instances plus Key Vault for TURN credentials.
- **Networking**: Private endpoints between App Service, Cosmos DB, and Service Bus. TURN relays deployed per region (NA/EU/APAC).
- **Infrastructure as Code**: Terraform modules under `infrastructure/terraform` will provision resources once backend work begins.

## Client Stubs (Current Phase)

- `AzureApiStub` returns deterministic payloads mirroring the future Azure contract to unblock client work.
- StoreKit flows store mocked receipt metadata for later upload once the entitlements App Service exists.
- Legit Mode telemetry caches data for eventual Cosmos DB sync via background uploader.
