
# HOPE-R

Minimal disaster-response prototype with only the requested working flow.

## Apps
- `civilian_app`: place emergency request + capture current GPS + send.
- `government_app`: view requests, automatically clustered incidents, exact request locations/details, and assign response services.
- `backend`: Express + PostgreSQL + Prisma.

## Automatic incident grouping
Active requests with the same emergency type within **500 meters** are attached to the same disaster/incident.

## Services
Ambulance, Food, Clothes, Service, Rescue Team.
Clicking a service creates an `ASSIGNED` record. There is intentionally no workflow after that.

## Run backend
1. Create PostgreSQL database `hope_r`.
2. Copy `backend/.env.example` to `backend/.env` and update credentials if needed.
3. Run:
   `cd backend`
   `npm install`
   `npx prisma generate`
   `npx prisma migrate dev --name init`
   `npm run dev`

Backend runs at `http://localhost:3000`.

## Run Flutter
From the HOPE-R root:
`powershell -ExecutionPolicy Bypass -File .\scripts\setup-flutter.ps1`

Then run either app with `flutter run`.
Android emulator uses `10.0.2.2:3000`; desktop uses `127.0.0.1:3000`.

## Scope intentionally excluded
Payments, donations, chat, complex auth, AI workflows, inventory, autonomous dispatch, mission workflows, extra apps/modules.
