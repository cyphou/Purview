# Assign different real AAD owners to all governance objects via Purview contacts API

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

# Real AAD users mapped to governance roles
$ownerAssignments = @(
    # ==========================================
    # APPLICATION SERVICES (12 RC + 6 SAP)
    # ==========================================
    # RC Site Services — owned by TotalEnergies site contacts
    @{ guid = "b139a1fd-0aae-45f7-9e63-0c26796240bd"; ownerId = "05f6fa36-d256-4af3-b6a7-5387b8622c1d"; ownerName = "Anis HEZAM"; expertId = "051372e9-30c4-4adb-886d-3815cf1b0c0e"; expertName = "Bastien JOURET"; role = "Site Steward - Leuna (DE)" }
    @{ guid = "b2b9207e-f0f6-426a-bbfa-0cb1e80f37b1"; ownerId = "051372e9-30c4-4adb-886d-3815cf1b0c0e"; ownerName = "Bastien JOURET"; expertId = "05f6fa36-d256-4af3-b6a7-5387b8622c1d"; expertName = "Anis HEZAM"; role = "Site Steward - Fos-sur-Mer (FR)" }
    @{ guid = "2550907e-8f0a-45f6-830e-fb58e6cdf154"; ownerId = "7f3cf5a1-2ecf-4b20-9883-777495d0f423"; ownerName = "Benoit SOLEILHAVOUP"; expertId = "94ea249e-67cc-4d39-b97c-6508c55fa2e5"; expertName = "iliasse.arsalane"; role = "Site Steward - Antwerp (BE)" }
    @{ guid = "1f8401ff-0754-4781-98fa-b4c47c33c1e2"; ownerId = "a8eea874-7e2f-463c-b1f4-a4a4b22165c2"; ownerName = "Josephine BOULANGER"; expertId = "51032cdc-4de8-43c8-9b28-c68de2964f8e"; expertName = "Lucas BATAILLARD"; role = "Site Steward - Donges (FR)" }
    @{ guid = "fed4a0de-cbfb-473d-b079-d3005be6feb5"; ownerId = "51032cdc-4de8-43c8-9b28-c68de2964f8e"; ownerName = "Lucas BATAILLARD"; expertId = "7e0ab2ae-3df3-4ad2-a074-9438887b4786"; expertName = "Saif Eddine JERBI"; role = "Site Steward - Lindsey (GB)" }
    @{ guid = "cffaccfd-f1d0-4efc-a28b-9d89801b9e44"; ownerId = "0de99c7b-3d4d-4ec0-96c2-3edfc50dfa5b"; ownerName = "Gerome SAUVE"; expertId = "05f6fa36-d256-4af3-b6a7-5387b8622c1d"; expertName = "Anis HEZAM"; role = "Site Steward - Normandy (FR)" }
    @{ guid = "207ef067-c9a3-4a99-9217-34c53a09d0b5"; ownerId = "7e0ab2ae-3df3-4ad2-a074-9438887b4786"; ownerName = "Saif Eddine JERBI"; expertId = "0de99c7b-3d4d-4ec0-96c2-3edfc50dfa5b"; expertName = "Gerome SAUVE"; role = "Site Steward - Grandpuits (FR)" }
    @{ guid = "7ad47dfd-4206-4a0f-8fb0-743e85bd0d6b"; ownerId = "94ea249e-67cc-4d39-b97c-6508c55fa2e5"; ownerName = "iliasse.arsalane"; expertId = "7f3cf5a1-2ecf-4b20-9883-777495d0f423"; expertName = "Benoit SOLEILHAVOUP"; role = "Site Steward - Port Arthur (US)" }
    @{ guid = "dd837cde-3095-4555-94a7-ed24cc01b424"; ownerId = "30748d91-ce23-404d-9b61-b166467547a6"; ownerName = "ramzi.bouyekhf"; expertId = "a8eea874-7e2f-463c-b1f4-a4a4b22165c2"; expertName = "Josephine BOULANGER"; role = "Site Steward - La Mede (FR)" }
    # Transversal services
    @{ guid = "e1087329-6515-475e-83e2-cceea03894ef"; ownerId = "a8eea874-7e2f-463c-b1f4-a4a4b22165c2"; ownerName = "Josephine BOULANGER"; expertId = "30748d91-ce23-404d-9b61-b166467547a6"; expertName = "ramzi.bouyekhf"; role = "RAMSES Product Owner" }
    @{ guid = "f0728644-4e46-4277-9776-802d234fe5a9"; ownerId = "7f3cf5a1-2ecf-4b20-9883-777495d0f423"; ownerName = "Benoit SOLEILHAVOUP"; expertId = "051372e9-30c4-4adb-886d-3815cf1b0c0e"; expertName = "Bastien JOURET"; role = "RADAR Product Owner" }
    @{ guid = "c14d7d2e-7351-490c-bb74-5bef9a297d39"; ownerId = "ddc92948-4a2b-4a8a-ab71-9e7f2dc9572f"; ownerName = "Zineb EL MAJOUDI"; expertId = "ec1b7a10-0ed1-4dac-a3cb-41cd27e5e82c"; expertName = "Mehdi Maachou"; role = "TDF SMINT Product Owner" }

    # ==========================================
    # GOVERNANCE DOMAINS (5)
    # ==========================================
    @{ guid = "befb3d6a-34cc-4464-ad8c-da0583257f21"; ownerId = "e8c4054b-55fd-4783-bc2f-a1ef32f8ea7b"; ownerName = "Finance Data Owner"; expertId = "619a0048-e2c0-466a-a611-a34521941024"; expertName = "Finance Steward"; role = "Finance & ESG Domain Steward" }
    @{ guid = "604c1ab0-47cb-4a4a-89cf-a737021e1592"; ownerId = "e457fece-a83a-43de-8fa8-7d2db10a5ec0"; ownerName = "Emilie Beau"; expertId = "3c8908f3-aeae-4e60-b7fd-e02dd554ab70"; expertName = "Marc Hadjeje"; role = "Customer & Sales Domain Steward" }
    @{ guid = "e2b53231-ca20-4e97-b7fe-dd995e7c6d5f"; ownerId = "fa5691c2-e976-4d52-8201-d884fa7d196b"; ownerName = "Marc Interne"; expertId = "e457fece-a83a-43de-8fa8-7d2db10a5ec0"; expertName = "Emilie Beau"; role = "HR & People Domain Steward" }
    @{ guid = "32272856-a0cc-4633-9354-ba300c1515f1"; ownerId = "0de99c7b-3d4d-4ec0-96c2-3edfc50dfa5b"; ownerName = "Gerome SAUVE"; expertId = "a8eea874-7e2f-463c-b1f4-a4a4b22165c2"; expertName = "Josephine BOULANGER"; role = "Operations Domain Steward" }
    @{ guid = "d0366806-b679-45a9-84e3-b147e4a9b16d"; ownerId = "0738cec4-3dd2-4d28-86bc-9585d85eb511"; ownerName = "Pierre DOUDET"; expertId = "ec1b7a10-0ed1-4dac-a3cb-41cd27e5e82c"; expertName = "Mehdi Maachou"; role = "Technology Domain Steward" }

    # ==========================================
    # ORGANIZATIONS (3)
    # ==========================================
    @{ guid = "efe8fb35-43af-454f-8af7-8ca66c6be5ca"; ownerId = "7d6d0d73-8eb2-4a9c-a4c8-ef6276adfdc0"; ownerName = "CFO"; expertId = "6617cad6-d329-4361-951a-9eacbbaa8049"; expertName = "System Administrator"; role = "Group Executive Sponsor" }
    @{ guid = "aa5af5df-5597-45ef-8a8c-9e736472441a"; ownerId = "0de99c7b-3d4d-4ec0-96c2-3edfc50dfa5b"; ownerName = "Gerome SAUVE"; expertId = "7f3cf5a1-2ecf-4b20-9883-777495d0f423"; expertName = "Benoit SOLEILHAVOUP"; role = "RC Division Lead" }
    @{ guid = "882ee27a-6b38-498d-98f0-27cd7ee79057"; ownerId = "4b31a349-c185-451c-961d-0e9bf7d898ad"; ownerName = "Emmanuel Deletang"; expertId = "d8e23944-1e02-4f05-b834-fdf5561352ab"; expertName = "Alexandre Fourdraine"; role = "Company B Lead" }

    # ==========================================
    # LINES OF BUSINESS (5)
    # ==========================================
    @{ guid = "51537710-b9ec-4ce8-a72d-991da02d5887"; ownerId = "94ea249e-67cc-4d39-b97c-6508c55fa2e5"; ownerName = "iliasse.arsalane"; expertId = "30748d91-ce23-404d-9b61-b166467547a6"; expertName = "ramzi.bouyekhf"; role = "Supply Chain LoB Owner" }
    @{ guid = "c83d2bff-d8d2-4e89-b8e6-2a3d3175f38d"; ownerId = "ddc92948-4a2b-4a8a-ab71-9e7f2dc9572f"; ownerName = "Zineb EL MAJOUDI"; expertId = "0738cec4-3dd2-4d28-86bc-9585d85eb511"; expertName = "Pierre DOUDET"; role = "Digital Services LoB Owner" }
    @{ guid = "34999082-9edb-4a5f-ba05-2cbe032f4645"; ownerId = "3c8908f3-aeae-4e60-b7fd-e02dd554ab70"; ownerName = "Marc Hadjeje"; expertId = "e457fece-a83a-43de-8fa8-7d2db10a5ec0"; expertName = "Emilie Beau"; role = "Analytics & BI LoB Owner" }
    @{ guid = "182e28fe-e3e0-4085-900d-24cdec281fae"; ownerId = "051372e9-30c4-4adb-886d-3815cf1b0c0e"; ownerName = "Bastien JOURET"; expertId = "0de99c7b-3d4d-4ec0-96c2-3edfc50dfa5b"; expertName = "Gerome SAUVE"; role = "Industrial Ops LoB Owner" }
    @{ guid = "225ecb41-153d-4366-9ce0-76b361cee3f9"; ownerId = "619a0048-e2c0-466a-a611-a34521941024"; ownerName = "Finance Steward"; expertId = "fa5691c2-e976-4d52-8201-d884fa7d196b"; expertName = "Marc Interne"; role = "Corporate Functions LoB Owner" }

    # ==========================================
    # DATA PRODUCTS (6 production)
    # ==========================================
    @{ guid = "c30a209a-8764-4b03-a95b-69f62ea3a64c"; ownerId = "e8c4054b-55fd-4783-bc2f-a1ef32f8ea7b"; ownerName = "Finance Data Owner"; expertId = "7d6d0d73-8eb2-4a9c-a4c8-ef6276adfdc0"; expertName = "CFO"; role = "Executive Dashboards Product Owner" }
    @{ guid = "495072be-66ff-4062-b122-1acd46efdd9d"; ownerId = "619a0048-e2c0-466a-a611-a34521941024"; ownerName = "Finance Steward"; expertId = "e8c4054b-55fd-4783-bc2f-a1ef32f8ea7b"; expertName = "Finance Data Owner"; role = "ESG Reporting Product Owner" }
    @{ guid = "efb1058d-5a3f-4464-b39a-bf4f1096b6cd"; ownerId = "e457fece-a83a-43de-8fa8-7d2db10a5ec0"; ownerName = "Emilie Beau"; expertId = "fa5691c2-e976-4d52-8201-d884fa7d196b"; expertName = "Marc Interne"; role = "Customer 360 Product Owner" }
    @{ guid = "1ae39b7b-8a9a-4a13-9670-fa0a479bfc69"; ownerId = "fa5691c2-e976-4d52-8201-d884fa7d196b"; ownerName = "Marc Interne"; expertId = "e457fece-a83a-43de-8fa8-7d2db10a5ec0"; expertName = "Emilie Beau"; role = "Workforce Analytics Product Owner" }
    @{ guid = "0d633bc1-5014-41c6-ad50-b9f4249bc565"; ownerId = "0de99c7b-3d4d-4ec0-96c2-3edfc50dfa5b"; ownerName = "Gerome SAUVE"; expertId = "051372e9-30c4-4adb-886d-3815cf1b0c0e"; expertName = "Bastien JOURET"; role = "Ops Performance Product Owner" }
    @{ guid = "25db6129-20d4-4ab8-9fef-f2e4e356ced5"; ownerId = "0738cec4-3dd2-4d28-86bc-9585d85eb511"; ownerName = "Pierre DOUDET"; expertId = "ec1b7a10-0ed1-4dac-a3cb-41cd27e5e82c"; expertName = "Mehdi Maachou"; role = "Platform Health Product Owner" }
)

$success = 0
$failed = 0

foreach ($item in $ownerAssignments) {
    try {
        # Get current entity to preserve attributes
        $entity = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity/guid/$($item.guid)?api-version=2022-03-01-preview" -Headers $headers
        $name = $entity.entity.attributes.name
        Write-Host "  $name -> Owner: $($item.ownerName), Expert: $($item.expertName)..." -NoNewline

        $payload = @{
            entity = @{
                typeName = $entity.entity.typeName
                guid = $item.guid
                attributes = $entity.entity.attributes
                contacts = @{
                    Owner = @(
                        @{ id = $item.ownerId; info = $item.role }
                    )
                    Expert = @(
                        @{ id = $item.expertId; info = $item.role }
                    )
                }
            }
        } | ConvertTo-Json -Depth 10

        $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
        Write-Host " OK" -ForegroundColor Green
        $success++
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Owners assigned: $success | Failed: $failed" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
