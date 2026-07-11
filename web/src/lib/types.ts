// Domain types shared by the API routes and the UI. These mirror the
// Swift models (dumpster/Sources and dumpsteriOS/Models) so the iOS JSON
// backup can be imported losslessly.

export type Category = 'action' | 'brainstorm' | 'resource';
export type Priority = 'high' | 'medium' | 'low' | 'backlog';

export const PRIORITY_ORDER: Record<Priority, number> = {
  high: 0,
  medium: 1,
  low: 2,
  backlog: 3,
};

export interface Item {
  id: string;
  text: string;
  category: Category;
  priority: Priority;
  done: boolean;
  doneAt: string | null;
  dueDate: string | null;
  url: string | null;
  urlTitle: string | null;
  notes: string | null;
  incorporatedIntoDoc: boolean;
  dismissedFromDoc: boolean;
  createdAt: string;
  tagIds: string[];
}

export interface Tag {
  id: string;
  name: string;
  createdAt: string;
}

export interface TagRelationship {
  id: string;
  parentTagId: string;
  childTagId: string;
}

export interface DailyDump {
  id: string;
  date: string; // yyyy-MM-dd
  content: string;
  updatedAt: string;
}

export interface MasterDoc {
  id: string;
  title: string;
  content: string; // markdown; headings are ## / ###
  createdAt: string;
  updatedAt: string;
  tagIds: string[];
}

export interface Win {
  id: string;
  text: string;
  artifact: string | null;
  createdAt: string;
}

// Result of processing one dump line's magic tags, so the UI can report
// what happened ("added action", "saved to doc…").
export interface ProcessResult {
  createdItems: { id: string; category: Category; priority: Priority; text: string }[];
  createdWin: string | null;
  savedToDocs: string[]; // doc titles
  deletedItems: number;
  registeredTags: string[];
}
