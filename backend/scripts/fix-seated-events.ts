/**
 * fix-seated-events.ts
 *
 * Converts all seated events to general-admission so they can be
 * purchased through the current cart → checkout flow.
 *
 * For each event with has_assigned_seating = true:
 *   1. Set has_assigned_seating = false
 *   2. For each ticket type: clear venue_section_id, set inventory_quantity
 *      (based on a reasonable default per section name)
 *
 * Run:  node --import tsx scripts/fix-seated-events.ts
 */
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
dotenv.config();

const prisma = new PrismaClient();

// Default capacities when converting from seated to GA
const SECTION_CAPACITY: Record<string, number> = {
  VIP: 200,
  Platea: 500,
  'Balcón': 300,
  Occidental: 600,
  Oriental: 600,
};
const DEFAULT_CAPACITY = 400;

async function main() {
  const seatedEvents = await prisma.events.findMany({
    where: { has_assigned_seating: true, status: 'PUBLISHED' },
    include: {
      event_ticket_types: { where: { is_active: true } },
    },
  });

  console.log(`Found ${seatedEvents.length} seated events to convert.\n`);

  for (const event of seatedEvents) {
    console.log(`Converting: ${event.title} (${event.slug})`);

    // 1. Set event to general admission
    await prisma.events.update({
      where: { id: event.id },
      data: { has_assigned_seating: false },
    });

    // 2. Update each ticket type
    for (const tt of event.event_ticket_types) {
      const capacity = SECTION_CAPACITY[tt.ticket_type_name] ?? DEFAULT_CAPACITY;
      await prisma.event_ticket_types.update({
        where: { id: tt.id },
        data: {
          venue_section_id: null,
          inventory_quantity: capacity,
        },
      });
      console.log(`  - ${tt.ticket_type_name}: venue_section_id=NULL, inventory=${capacity}`);
    }

    console.log(`  ✓ Done\n`);
  }

  console.log('All seated events converted to general admission.');
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  prisma.$disconnect();
  process.exit(1);
});
