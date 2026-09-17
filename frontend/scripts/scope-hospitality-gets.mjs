import fs from 'node:fs'
import path from 'node:path'

const dir = path.resolve('src/views/admin/hotel')
const updates = [
  ['HotelCalendarView.vue', 'HOTEL_CALENDAR_KINDS'],
  ['HotelRoomsView.vue', 'HOTEL_ROOM_KINDS'],
  ['HotelHousekeepingView.vue', 'HOTEL_HOUSEKEEPING_KINDS'],
  ['HotelConciergeView.vue', 'HOTEL_CONCIERGE_KINDS'],
]

for (const [file, kinds] of updates) {
  const full = path.join(dir, file)
  let s = fs.readFileSync(full, 'utf8')
  if (!s.includes('api/hospitality')) {
    s = s.replace(
      "import { api, extractApiErrorMessage } from '../../../api/client'",
      `import { api, extractApiErrorMessage } from '../../../api/client'\nimport { hospitalitySnapshotPath, ${kinds} } from '../../../api/hospitality'`,
    )
  }
  s = s.replaceAll(
    "api.get<{ data: { docs: Doc[] } }>('/hospitality')",
    `api.get<{ data: { docs: Doc[] } }>(hospitalitySnapshotPath([...${kinds}]))`,
  )
  fs.writeFileSync(full, s)
  console.log('updated', file)
}
