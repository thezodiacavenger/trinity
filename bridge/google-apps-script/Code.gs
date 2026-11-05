/**
 * Trinity Bridge — Google Apps Script web app.
 *
 * Reads TODAY from your calendar and returns only categories and minutes, never titles,
 * attendees or locations. The watch never sees what a meeting is about.
 *
 * Setup (5 minutes):
 *   1. script.google.com → New project → paste this file.
 *   2. Project Settings → Script properties → add TRINITY_TOKEN = <a long random string>.
 *   3. Deploy → New deployment → Web app → Execute as: Me, Who has access: Anyone.
 *   4. In Garmin Connect → Trinity watch face settings: paste the /exec URL and the token.
 *
 * Tag events however you like; the rules below match keywords in the title (case-insensitive).
 * Events with other guests that match nothing else are treated as meetings.
 */

const RULES = [
  { cat: 'READ',   words: ['read', 'reading', 'book'] },
  { cat: 'TRAIN',  words: ['gym', 'run', 'ride', 'swim', 'workout', 'training', 'lift', 'yoga', 'spin', 'hike', 'tennis', 'golf'] },
  { cat: 'LUNCH',  words: ['lunch', 'breakfast'] },
  { cat: 'PERS',   words: ['personal', 'family', 'kids', 'dinner', 'date night', 'doctor', 'dentist', 'appointment', 'school', 'pickup'] },
  { cat: 'FOCUS',  words: ['focus', 'deep work', 'hold', 'blocked', 'prep'] },
  { cat: 'TRAVEL', words: ['flight', 'travel', 'drive', 'commute', 'airport'] },
];

/** Pure function so it can be tested outside Apps Script. */
function categorize(title, guestCount) {
  const t = (title || '').toLowerCase();
  for (const rule of RULES) {
    if (rule.words.some(w => new RegExp('\\b' + w + '\\b').test(t))) return rule.cat;
  }
  return guestCount > 0 ? 'MTG' : 'FOCUS';
}

/** Pure summary over plain event objects: {title, start: Date, end: Date, guests: n}. */
function summarize(events, now) {
  const out = { v: 1, meet: 0, pers: 0, read: 0, train: 0, focus: 0, lunch: 0, travel: 0, nIn: null, nCat: null };
  const key = { MTG: 'meet', PERS: 'pers', READ: 'read', TRAIN: 'train', FOCUS: 'focus', LUNCH: 'lunch', TRAVEL: 'travel' };
  let next = null;
  for (const ev of events) {
    const cat = categorize(ev.title, ev.guests);
    out[key[cat]] += Math.round((ev.end - ev.start) / 60000);
    if (ev.start > now && (!next || ev.start < next.start)) next = { start: ev.start, cat };
  }
  if (next) {
    out.nIn = Math.round((next.start - now) / 60000);
    out.nCat = next.cat;
  }
  return out;
}

function doGet(e) {
  const expected = PropertiesService.getScriptProperties().getProperty('TRINITY_TOKEN');
  if (!expected || !e || !e.parameter || e.parameter.token !== expected) {
    return json_({ error: 'unauthorized' });
  }
  const now = new Date();
  const start = new Date(now); start.setHours(0, 0, 0, 0);
  const end = new Date(now); end.setHours(23, 59, 59, 999);

  const events = CalendarApp.getDefaultCalendar().getEvents(start, end)
    .filter(ev => !ev.isAllDayEvent())
    .filter(ev => {
      const s = ev.getMyStatus();
      return s !== CalendarApp.GuestStatus.NO;
    })
    .map(ev => ({
      title: ev.getTitle(),
      start: ev.getStartTime(),
      end: ev.getEndTime(),
      guests: ev.getGuestList().length,
    }));

  return json_(summarize(events, now));
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

if (typeof module !== 'undefined') module.exports = { categorize, summarize };
