import "dotenv/config";
import express from "express";
import cors from "cors";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const prisma = new PrismaClient({
  adapter: new PrismaPg({
    connectionString: process.env.DATABASE_URL!,
  }),
});

const app = express();

app.use(cors());
app.use(express.json());

const PORT = Number(process.env.PORT ?? 3000);

// Nearby requests within 500 meters become one incident.
const RADIUS_KM = 0.5;

const distanceKm = (
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
) => {
  const earthRadius = 6371;
  const radians = Math.PI / 180;

  const dLat = (lat2 - lat1) * radians;
  const dLon = (lon2 - lon1) * radians;

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * radians) *
      Math.cos(lat2 * radians) *
      Math.sin(dLon / 2) ** 2;

  return (
    earthRadius *
    2 *
    Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  );
};

const getPriority = (
  people: number,
  injured: number,
  trapped: number,
) =>
  trapped > 0 || injured >= 3 || people >= 10
    ? "CRITICAL"
    : injured > 0 || people >= 5
      ? "HIGH"
      : "MEDIUM";

app.get("/", (_, res) =>
  res.json({
    success: true,
    message: "HOPE-R API is running",
  }),
);

app.get("/health", (_, res) =>
  res.json({
    success: true,
  }),
);

/* =========================================================
   CREATE EMERGENCY REQUEST
========================================================= */

app.post("/requests", async (req, res) => {
  try {
    const {
      name,
      phone,
      type,
      description,
      latitude,
      longitude,
      people = 1,
      injured = 0,
      trapped = 0,
    } = req.body;

    if (
      !name ||
      !phone ||
      !type ||
      latitude === undefined ||
      longitude === undefined
    ) {
      return res.status(400).json({
        success: false,
        message:
          "Name, phone, type and current location are required.",
      });
    }

    const lat = Number(latitude);
    const lon = Number(longitude);

    const p = Math.max(1, Number(people));
    const i = Math.max(0, Number(injured));
    const t = Math.max(0, Number(trapped));

    /* -------------------------------------------------------
       CIVILIAN
    ------------------------------------------------------- */

    const civilian = await prisma.civilian.upsert({
      where: {
        phone: String(phone),
      },
      update: {
        name: String(name),
      },
      create: {
        name: String(name),
        phone: String(phone),
      },
    });

    /* -------------------------------------------------------
       EMERGENCY REQUEST
    ------------------------------------------------------- */

    const request = await prisma.emergencyRequest.create({
      data: {
        type: String(type),
        description: description?.trim() || null,
        latitude: lat,
        longitude: lon,
        people: p,
        injured: i,
        trapped: t,
        civilianId: civilian.id,
      },
    });

    /* -------------------------------------------------------
       SMART INCIDENT CLUSTERING
       
       IMPORTANT:
       Emergency TYPE is NOT used for clustering.

       Example:
       Fire + Medical + Collapse
       within 500m
       =
       ONE INCIDENT
    ------------------------------------------------------- */

    const candidates = await prisma.disaster.findMany({
      where: {
        status: "ACTIVE",
      },
    });

    // Find the nearest active incident within 500m.
    let disaster = candidates
      .map((candidate) => ({
        candidate,
        distance: distanceKm(
          lat,
          lon,
          candidate.latitude,
          candidate.longitude,
        ),
      }))
      .filter((item) => item.distance <= RADIUS_KM)
      .sort((a, b) => a.distance - b.distance)
      .map((item) => item.candidate)[0];

    let action = "ATTACHED";

    /* -------------------------------------------------------
       NO NEARBY INCIDENT
       -> CREATE NEW INCIDENT
    ------------------------------------------------------- */

    if (!disaster) {
      action = "CREATED";

      disaster = await prisma.disaster.create({
        data: {
          type: String(type),
          latitude: lat,
          longitude: lon,
          requestCount: 1,
          people: p,
          injured: i,
          trapped: t,
          priority: getPriority(p, i, t),
        },
      });
    }

    /* -------------------------------------------------------
       NEARBY INCIDENT FOUND
       -> ATTACH REQUEST
    ------------------------------------------------------- */

    else {
      const totalPeople = disaster.people + p;
      const totalInjured = disaster.injured + i;
      const totalTrapped = disaster.trapped + t;

      /*
       * If different emergency types enter the same location,
       * mark the incident as MULTI-EMERGENCY.
       *
       * Individual requests still preserve their original type.
       */
      const incidentType =
        disaster.type === String(type)
          ? disaster.type
          : "MULTI-EMERGENCY";

      disaster = await prisma.disaster.update({
        where: {
          id: disaster.id,
        },
        data: {
          type: incidentType,
          requestCount: {
            increment: 1,
          },
          people: totalPeople,
          injured: totalInjured,
          trapped: totalTrapped,
          priority: getPriority(
            totalPeople,
            totalInjured,
            totalTrapped,
          ),
        },
      });
    }

    /* -------------------------------------------------------
       LINK REQUEST TO INCIDENT
    ------------------------------------------------------- */

    await prisma.emergencyRequest.update({
      where: {
        id: request.id,
      },
      data: {
        disasterId: disaster.id,
      },
    });

    return res.status(201).json({
      success: true,
      requestId: request.id,
      disasterId: disaster.id,
      action,
      message:
        action === "CREATED"
          ? "New incident created."
          : "Request attached to nearby incident.",
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      message: "Unable to create request.",
    });
  }
});

/* =========================================================
   GET ALL REQUESTS
========================================================= */

app.get("/requests", async (_, res) => {
  try {
    const data = await prisma.emergencyRequest.findMany({
      orderBy: {
        createdAt: "desc",
      },
      include: {
        civilian: true,
        disaster: true,
      },
    });

    return res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      message: "Unable to fetch requests.",
    });
  }
});

/* =========================================================
   GET ALL INCIDENTS
========================================================= */

app.get("/disasters", async (_, res) => {
  try {
    const data = await prisma.disaster.findMany({
      orderBy: {
        createdAt: "desc",
      },
      include: {
        requests: {
          include: {
            civilian: true,
          },
        },
        assignments: true,
      },
    });

    return res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      message: "Unable to fetch incidents.",
    });
  }
});

/* =========================================================
   ASSIGN RESPONSE SERVICE
========================================================= */

app.post("/disasters/:id/assign", async (req, res) => {
  try {
    const services = [
      "Ambulance",
      "Food",
      "Clothes",
      "Service",
      "Rescue Team",
    ];

    const service = String(req.body.service ?? "");

    if (!services.includes(service)) {
      return res.status(400).json({
        success: false,
        message: "Invalid service",
      });
    }

    const id = Number(req.params.id);

    const disaster = await prisma.disaster.findUnique({
      where: {
        id,
      },
    });

    if (!disaster) {
      return res.status(404).json({
        success: false,
        message: "Incident not found",
      });
    }

    const data = await prisma.assignment.create({
      data: {
        disasterId: id,
        service,
        status: "ASSIGNED",
      },
    });

    return res.status(201).json({
      success: true,
      data,
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      message: "Unable to assign service.",
    });
  }
});

/* =========================================================
   START SERVER
========================================================= */

app.listen(PORT, () => {
  console.log(`HOPE-R API: http://localhost:${PORT}`);
});