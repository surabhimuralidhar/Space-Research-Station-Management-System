# srs_gui.py
"""
Space Research Station GUI (cyborg theme)
Run:
  pip install ttkbootstrap mysql-connector-python pandas
  python srs_gui.py
"""
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import ttkbootstrap as tb
import mysql.connector
from mysql.connector import Error
import csv
from datetime import datetime

# ---------- CONFIG ----------
HOST = "localhost"
DATABASE = "srsdb"

# Map roles -> DB credentials (match your created users)
ROLE_CREDENTIALS = {
    "admin":    {"user": "admin_srs",    "password": "Admin@123"},
    "operator": {"user": "operator_srs", "password": "Op@123"},
    "viewer":   {"user": "viewer_srs",   "password": "View@123"}
}

# Default tables to list in dropdown (you can modify if you added/removed tables)
TABLES_TO_SHOW = [
    'Astronauts','AstronautSkills','Missions','StationModules','Resources','Supplies',
    'LifeSupportSystems','Spacecrafts','Experiments','Schedules','MedicalRecords',
    'ResourceAllocations','Communications','Anomalies','Astronaut_Missions',
    'Mission_Spacecraft','Mission_Modules','Experiment_Astronauts'
]

VIEWS = ['vw_LowStock','vw_ActiveMissions','vw_ExperimentSummary','vw_ModuleAnomalies','vw_AstronautHealth']

# ---------- Helper DB functions ----------
def create_conn_for_role(role):
    creds = {
        "admin": ("admin_srs", "Admin@123"),
        "operator": ("operator_srs", "Operator@123"),
        "viewer": ("viewer_srs", "Viewer@123"),
    }
    user, pwd = creds[role.lower()]
    return mysql.connector.connect(
        host="localhost",
        user=user,
        password=pwd,
        database="srsdb"
    )


def test_connect_for_role(role):
    try:
        conn = create_conn_for_role(role)
        conn.close()
        return True, ""
    except Exception as e:
        return False, str(e)

# ---------- Main GUI ----------
class SRSApp:
    def __init__(self, role=None):
        # Create themed window
        self.root = tb.Window(themename="cyborg")
        self.root.title("SRSMS - Space Research Station")
        self.root.geometry("1200x780")
        self.conn = None
        self.role = None
        self.current_table = tk.StringVar()
        self.search_var = tk.StringVar()

        # If role passed (for direct start) else show login
        if role:
            ok, msg = test_connect_for_role(role)
            if not ok:
                messagebox.showerror("Connection failed", msg)
                self._build_login_ui()
            else:
                self._login(role)
        else:
            self._build_login_ui()
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)
        self.root.mainloop()

    # ---------------- Login ----------------
    def _build_login_ui(self):
        for w in self.root.winfo_children():
            w.destroy()

        frm = ttk.Frame(self.root, padding=20)
        frm.pack(expand=True)

        ttk.Label(frm, text="SRSMS - Login", font=("Helvetica", 20)).pack(pady=(0,12))
        ttk.Label(frm, text="Select role to login:", font=("Helvetica", 12)).pack()

        self.role_cb = ttk.Combobox(frm, values=list(ROLE_CREDENTIALS.keys()), state="readonly")
        self.role_cb.set("admin")
        self.role_cb.pack(pady=8)

        btn_frame = ttk.Frame(frm)
        btn_frame.pack(pady=12)
        ttk.Button(btn_frame, text="Test Connection", command=self._test_conn).grid(row=0,column=0,padx=6)
        ttk.Button(btn_frame, text="Login", command=self._on_login).grid(row=0,column=1,padx=6)
        ttk.Button(btn_frame, text="Quit", command=self.on_close).grid(row=0,column=2,padx=6)

    def _test_conn(self):
        role = self.role_cb.get()
        ok, msg = test_connect_for_role(role)
        if ok:
            messagebox.showinfo("Connection", f"Connection OK for {role}")
        else:
            messagebox.showerror("Connection failed", msg)

    def _on_login(self):
        role = self.role_cb.get()
        try:
            conn = create_conn_for_role(role)
            # quick test
            cur = conn.cursor()
            cur.execute("SELECT 1")
            cur.fetchone()
            cur.close()
        except Exception as e:
            messagebox.showerror("Login failed", str(e))
            return
        self._login(role, conn)

    def _login(self, role, conn=None):
        self.role = role.lower()
        try:
            if conn is None:
                self.conn = create_conn_for_role(self.role)
            else:
                self.conn = conn
        except Exception as e:
            messagebox.showerror("DB Error", str(e))
            self._build_login_ui()
            return
        # build main UI
        self._build_main_ui()

    # ---------------- Main UI ----------------
    def _build_main_ui(self):
        for w in self.root.winfo_children():
            w.destroy()

        topbar = ttk.Frame(self.root, padding=(8,8))
        topbar.pack(fill='x')

        ttk.Label(topbar, text=f"SRSMS — Role: {self.role}", font=("Helvetica", 14)).pack(side='left')

        # ribbon-style groups
        ribbon = ttk.Frame(self.root)
        ribbon.pack(fill='x', padx=6, pady=(6,0))

        # Tables group
        grp_tables = ttk.Labelframe(ribbon, text="Tables", padding=6)
        grp_tables.pack(side='left', padx=6)
        self.tbl_combo = ttk.Combobox(grp_tables, values=TABLES_TO_SHOW, state='readonly', width=30, textvariable=self.current_table)
        self.tbl_combo.pack(pady=4)
        ttk.Button(grp_tables, text="Load Table", command=self.load_table).pack(pady=2)
        ttk.Button(grp_tables, text="Refresh Tables List", command=self._reload_table_list).pack(pady=2)

        # CRUD group
        grp_crud = ttk.Labelframe(ribbon, text="CRUD", padding=6)
        grp_crud.pack(side='left', padx=6)
        self.btn_insert = ttk.Button(grp_crud, text="Insert", command=self._insert)
        self.btn_insert.grid(row=0, column=0, padx=4, pady=2)
        self.btn_update = ttk.Button(grp_crud, text="Update", command=self._update)
        self.btn_update.grid(row=0, column=1, padx=4, pady=2)
        self.btn_delete = ttk.Button(grp_crud, text="Delete", command=self._delete)
        self.btn_delete.grid(row=0, column=2, padx=4, pady=2)
        ttk.Button(grp_crud, text="Refresh", command=self.load_table).grid(row=0, column=3, padx=4)
        ttk.Button(grp_crud, text="Export CSV", command=self._export_csv).grid(row=0, column=4, padx=4)

        # <-- ADD HERE -->
        if self.role == "viewer":
            self.btn_insert.configure(state="disabled")
            self.btn_update.configure(state="disabled")
            self.btn_delete.configure(state="disabled")
        elif self.role == "operator":
            self.btn_insert.configure(state="normal")
            self.btn_update.configure(state="normal")
            self.btn_delete.configure(state="disabled")
        elif self.role == "admin":
            self.btn_insert.configure(state="normal")
            self.btn_update.configure(state="normal")
            self.btn_delete.configure(state="normal")

        # Procedures & Functions group
        grp_pf = ttk.Labelframe(ribbon, text="Procs/Funcs / Triggers", padding=6)
        grp_pf.pack(side='left', padx=6)
        ttk.Button(grp_pf, text="sp_allocate_supply", command=self._open_allocate_ui).grid(row=0, column=0, padx=4, pady=2)
        ttk.Button(grp_pf, text="sp_create_experiment", command=self._open_createexp_ui).grid(row=0, column=1, padx=4, pady=2)
        ttk.Button(grp_pf, text="fn_mission_duration", command=self._open_fn_mission_ui).grid(row=1, column=0, padx=4, pady=2)
        ttk.Button(grp_pf, text="fn_remaining_supply", command=self._open_fn_supply_ui).grid(row=1, column=1, padx=4, pady=2)
        ttk.Button(grp_pf, text="Audit Log (refresh)", command=self._refresh_audit).grid(row=2, column=0, padx=4, pady=2)

        # Queries group
        grp_q = ttk.Labelframe(ribbon, text="Queries", padding=6)
        grp_q.pack(side='left', padx=6)
        ttk.Button(grp_q, text="Join: Astronaut assignments", command=self._run_join).grid(row=0,column=0,padx=4,pady=2)
        ttk.Button(grp_q, text="Aggregate: Avg Oxygen", command=self._run_aggregate).grid(row=0,column=1,padx=4,pady=2)
        ttk.Button(grp_q, text="Nested: Above-average experiments", command=self._run_nested).grid(row=0,column=2,padx=4,pady=2)

        # Custom SQL
        grp_sql = ttk.Labelframe(ribbon, text="Custom SELECT (read-only)", padding=6)
        grp_sql.pack(side='left', padx=6)
        self.custom_sql_entry = ttk.Entry(grp_sql, width=60)
        self.custom_sql_entry.pack(side='left', padx=4, pady=4)
        ttk.Button(grp_sql, text="Run SELECT", command=self._run_custom_sql).pack(side='left', padx=4)



        # Search bar
        searchbar = ttk.Frame(self.root, padding=(6,6))
        searchbar.pack(fill='x')
        ttk.Label(searchbar, text="Search (simple substring filter):").pack(side='left', padx=(4,6))
        self.search_entry = ttk.Entry(searchbar, textvariable=self.search_var, width=40)
        self.search_entry.pack(side='left', padx=4)
        ttk.Button(searchbar, text="Apply", command=self._apply_search).pack(side='left', padx=4)
        ttk.Button(searchbar, text="Clear", command=self._clear_search).pack(side='left', padx=4)

        # Main content: left=table tree, right=audit/log/details
        content = ttk.Panedwindow(self.root, orient='horizontal')
        content.pack(fill='both', expand=True, padx=6, pady=6)

        # Left: data tree
        left = ttk.Frame(content)
        content.add(left, weight=3)

        self.tree = ttk.Treeview(left, show='headings')
        self.tree.pack(fill='both', expand=True, side='left')
        self.tree_scroll = ttk.Scrollbar(left, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=self.tree_scroll.set)
        self.tree_scroll.pack(side='right', fill='y')
        self.tree.bind("<<TreeviewSelect>>", self._on_row_select)

        # Right: audit / details panel
        right = ttk.Frame(content, width=360)
        content.add(right, weight=1)
        ttk.Label(right, text="Audit / Details", font=("Helvetica", 12)).pack(anchor='w', padx=6, pady=(6,2))
        self.audit_tree = ttk.Treeview(right, columns=['AuditID','TableName','Operation','KeyData','NewRow','ChangedAt'], show='headings', height=12)
        for c in ['AuditID','TableName','Operation','KeyData','NewRow','ChangedAt']:
            self.audit_tree.heading(c, text=c)
            self.audit_tree.column(c, width=100)
        self.audit_tree.pack(fill='both', expand=True, padx=6, pady=6)

        # load default table list into combobox
        self._reload_table_list()

        # optional: initial load first table
        if TABLES_TO_SHOW:
            self.current_table.set(TABLES_TO_SHOW[0])
            # don't auto-load to avoid slow start; user presses Load Table

    # ---------------- utility UI helpers ----------------
    def _reload_table_list(self):
        # try to read tables from DB to keep list current
        try:
            cur = self.conn.cursor()
            cur.execute("SHOW TABLES")
            rows = cur.fetchall()
            tables = [r[0] for r in rows]
            # keep only tables we want (or show all)
            # we prefer to show the original TABLES_TO_SHOW order if present
            ordered = [t for t in TABLES_TO_SHOW if t in tables]
            # append any extra ones at end
            extras = [t for t in tables if t not in ordered]
            final = ordered + extras
            self.tbl_combo['values'] = final
            cur.close()
        except Exception:
            # fallback to static list
            self.tbl_combo['values'] = TABLES_TO_SHOW

    def _on_row_select(self, _ev):
        # display selected row details in audit panel or do nothing
        pass

    # ---------------- Load table ----------------
    def load_table(self):
        tbl = self.current_table.get()
        if not tbl:
            messagebox.showwarning("Select table", "Please select a table to load.")
            return
        try:
            cur = self.conn.cursor(dictionary=True)
            cur.execute(f"SELECT * FROM `{tbl}` LIMIT 2000")
            rows = cur.fetchall()
            cols = list(rows[0].keys()) if rows else []
            # configure tree
            self.tree.delete(*self.tree.get_children())
            self.tree['columns'] = cols
            for c in cols:
                self.tree.heading(c, text=c)
                self.tree.column(c, width=130, anchor='center')
            for r in rows:
                vals = [r[c] for c in cols]
                # convert None to empty string for display
                vals = [("" if v is None else v) for v in vals]
                self.tree.insert("", "end", values=vals)
            cur.close()
            # clear search field
            self.search_var.set("")
        except Exception as e:
            messagebox.showerror("Load error", str(e))

    # ---------------- Search ----------------
    def _apply_search(self):
        q = self.search_var.get().strip().lower()
        if not q:
            messagebox.showinfo("Search", "Type a substring to filter rows.")
            return
        # simple client-side filter: hide rows that don't contain substring in any column text
        for iid in self.tree.get_children():
            values = self.tree.item(iid, 'values')
            joined = " ".join([str(v).lower() for v in values])
            if q in joined:
                self.tree.reattach(iid, '', 'end')
            else:
                self.tree.detach(iid)

    def _clear_search(self):
        self.search_var.set("")
        # reattach all children (works if filtered previously)
        for iid in self.tree.get_children(''):
            pass
        # simplest approach: reload the table
        self.load_table()

    # ---------------- Export CSV ----------------
    def _export_csv(self):
        cols = self.tree['columns']
        if not cols:
            messagebox.showinfo("Export", "No data to export")
            return
        rows = [self.tree.item(iid)['values'] for iid in self.tree.get_children()]
        default_name = f"{self.current_table.get() or 'export'}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        fn = filedialog.asksaveasfilename(defaultextension=".csv", filetypes=[("CSV files","*.csv")], initialfile=default_name)
        if not fn:
            return
        try:
            with open(fn, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(cols)
                for r in rows:
                    writer.writerow(r)
            messagebox.showinfo("Exported", f"Saved to {fn}")
        except Exception as e:
            messagebox.showerror("Export error", str(e))

    # ---------------- CRUD operations ----------------
    def _insert(self):
        if self.role == "viewer":
            messagebox.showwarning("Permission", "Viewer cannot insert.")
            return
        tbl = self.current_table.get()
        if not tbl:
            messagebox.showwarning("Select table", "Choose a table first.")
            return
        InsertWindow(self.conn, tbl, self.load_table)

    def _update(self):
        if self.role not in ("admin","operator"):
            messagebox.showwarning("Permission", "Only admin/operator can update.")
            return
        sel = self.tree.selection()
        if not sel:
            messagebox.showwarning("Select row", "Select a row to update.")
            return
        values = self.tree.item(sel[0])['values']
        tbl = self.current_table.get()
        UpdateWindow(self.conn, tbl, values, self.load_table)

    def _delete(self):
        if self.role != "admin":
            messagebox.showwarning("Permission", "Only admin can delete.")
            return
        sel = self.tree.selection()
        if not sel:
            messagebox.showwarning("Select row", "Select a row to delete.")
            return
        values = self.tree.item(sel[0])['values']
        tbl = self.current_table.get()
        # determine primary key(s)
        try:
            cur = self.conn.cursor()
            cur.execute(f"SHOW KEYS FROM `{tbl}` WHERE Key_name = 'PRIMARY'")
            pk_rows = cur.fetchall()
            if not pk_rows:
                messagebox.showwarning("No PK", "Table has no primary key; cannot safely delete via GUI.")
                cur.close()
                return
            # pk_rows may contain multiple columns (composite)
            pk_cols = [r[4] for r in pk_rows]  # Column_name is index 4 in SHOW KEYS result
            # build WHERE using first N values from displayed row (assumes order in tree matches DESCRIBE)
            # safer: fetch column order via DESCRIBE
            cur.execute(f"DESCRIBE `{tbl}`")
            desc = cur.fetchall()
            col_names = [r[0] for r in desc]
            # map pk column to value using column index
            where_parts = []
            params = []
            for pk in pk_cols:
                if pk in col_names:
                    idx = col_names.index(pk)
                    val = values[idx]
                    where_parts.append(f"`{pk}` = %s")
                    params.append(val)
                else:
                    messagebox.showerror("Error", f"Primary key column {pk} not found in table columns.")
                    cur.close()
                    return
            sql = f"DELETE FROM `{tbl}` WHERE " + " AND ".join(where_parts)
            ok = messagebox.askyesno("Confirm", f"Delete selected row from {tbl}?")
            if not ok:
                cur.close(); return
            cur.execute(sql, params)
            self.conn.commit()
            cur.close()
            messagebox.showinfo("Deleted", "Row deleted.")
            self.load_table()
        except Exception as e:
            messagebox.showerror("Delete failed", str(e))

    # ---------------- Procedures / functions UIs ----------------
    def _open_allocate_ui(self):
        if self.role == "viewer":
            messagebox.showwarning("Permission", "Viewer cannot call procedures.")
            return
        AllocateWindow(self.conn, self.load_table)

    def _open_createexp_ui(self):
        if self.role == "viewer":
            messagebox.showwarning("Permission", "Viewer cannot call procedures.")
            return
        CreateExperimentWindow(self.conn, self.load_table)

    def _open_fn_mission_ui(self):
        FnMissionWindow(self.conn)

    def _open_fn_supply_ui(self):
        FnSupplyWindow(self.conn)

    # ---------------- trigger demos & audit ----------------
    def _refresh_audit(self):
        try:
            cur = self.conn.cursor(dictionary=True)
            cur.execute("SELECT AuditID, TableName, Operation, KeyData, NewRow, ChangedAt FROM AuditLog ORDER BY ChangedAt DESC LIMIT 200")
            rows = cur.fetchall()
            self.audit_tree.delete(*self.audit_tree.get_children())
            for r in rows:
                self.audit_tree.insert('', 'end', values=(r['AuditID'], r['TableName'], r['Operation'], r['KeyData'], str(r['NewRow']), str(r['ChangedAt'])))
            cur.close()
        except Exception as e:
            messagebox.showerror("Audit error", str(e))

    # ---------------- Example queries (join/aggregate/nested) ----------------
    def _run_join(self):
        sql = """
        SELECT A.AstronautID, CONCAT(A.FirstName,' ',A.LastName) AS Name, M.MissionName, AM.Role
        FROM Astronauts A
        JOIN Astronaut_Missions AM ON A.AstronautID = AM.AstronautID
        JOIN Missions M ON M.MissionID = AM.MissionID
        LIMIT 500
        """
        self._run_query_and_show(sql)

    def _run_aggregate(self):
        sql = """
        SELECT SM.ModuleName, AVG(LSS.OxygenLevel) AS AvgOxygen
        FROM LifeSupportSystems LSS
        JOIN StationModules SM ON SM.ModuleID = LSS.ModuleID
        GROUP BY SM.ModuleName
        """
        self._run_query_and_show(sql)

    def _run_nested(self):
        sql = """
        SELECT m.MissionID, m.MissionName, COUNT(e.ExperimentID) AS expCount
        FROM Missions m
        LEFT JOIN Experiments e ON m.MissionID = e.MissionID
        GROUP BY m.MissionID, m.MissionName
        HAVING COUNT(e.ExperimentID) > (
            SELECT AVG(t.cnt) FROM (
                SELECT COUNT(*) AS cnt FROM Experiments GROUP BY MissionID
            ) AS t
        ) LIMIT 500
        """
        self._run_query_and_show(sql)

    def _run_custom_sql(self):
        s = self.custom_sql_entry.get().strip()
        if not s:
            messagebox.showwarning("No SQL", "Type a SELECT query to run.")
            return
        # safety: only allow SELECT queries
        if not s.lower().startswith("select"):
            messagebox.showwarning("Only SELECT", "Only read-only SELECT queries are allowed here.")
            return
        self._run_query_and_show(s)

    def _run_query_and_show(self, sql):
        try:
            cur = self.conn.cursor(dictionary=True)
            cur.execute(sql)
            rows = cur.fetchall()
            cur.close()
            if not rows:
                messagebox.showinfo("Query", "No rows returned.")
                return
            cols = list(rows[0].keys())
            # set tree
            self.tree.delete(*self.tree.get_children())
            self.tree['columns'] = cols
            for c in cols:
                self.tree.heading(c, text=c)
                self.tree.column(c, width=140)
            for r in rows:
                vals = [r[c] for c in cols]
                vals = [("" if v is None else v) for v in vals]
                self.tree.insert('', 'end', values=vals)
        except Exception as e:
            messagebox.showerror("Query error", str(e))

    # ---------------- Close ----------------
    def on_close(self):
        try:
            if self.conn:
                self.conn.close()
        except:
            pass
        self.root.destroy()


# ---------- Insert / Update windows ----------
class InsertWindow(tk.Toplevel):
    def __init__(self, conn, table, refresh_callback):
        super().__init__()
        self.conn = conn
        self.table = table
        self.refresh_callback = refresh_callback
        self.title(f"Insert into {table}")
        self.geometry("560x580")
        self.configure(bg="#0a0f14")

        try:
            # get column metadata
            cur = self.conn.cursor()
            cur.execute(f"DESCRIBE `{table}`")
            cols = cur.fetchall()
            cur.close()
        except Exception as e:
            messagebox.showerror("Error", f"Cannot describe table: {e}")
            self.destroy()
            return

        # store column descriptors: (Field, Type, Null, Key, Default, Extra)
        self.cols = cols
        self.entries = {}
        frame = ttk.Frame(self)
        frame.pack(padx=8, pady=8, fill='both', expand=True)
        canvas = tk.Canvas(frame, bg="#0a0f14")
        canvas.pack(side='left', fill='both', expand=True)
        scroll = ttk.Scrollbar(frame, orient="vertical", command=canvas.yview)
        scroll.pack(side='right', fill='y')
        canvas.configure(yscrollcommand=scroll.set)
        inner = ttk.Frame(canvas)
        canvas.create_window((0,0), window=inner, anchor='nw')

        # Build form: skip auto_increment primary keys (don't insert them)
        r = 0
        for col in cols:
            fname = col[0]
            fextra = col[5]  # extra contains 'auto_increment' if present
            if fextra and 'auto_increment' in fextra.lower():
                # show as read-only label (empty)
                ttk.Label(inner, text=f"{fname} (auto)", width=30).grid(row=r, column=0, sticky='w', padx=6, pady=4)
                ttk.Label(inner, text="(auto)", width=30).grid(row=r, column=1, sticky='w', padx=6, pady=4)
                r += 1
                continue
            ttk.Label(inner, text=fname, width=30).grid(row=r, column=0, sticky='w', padx=6, pady=4)
            ent = ttk.Entry(inner, width=40)
            ent.grid(row=r, column=1, padx=6, pady=4)
            self.entries[fname] = ent
            r += 1

        inner.update_idletasks()
        canvas.config(scrollregion=canvas.bbox("all"))

        ttk.Button(self, text="Insert", command=self._submit).pack(pady=8)

    def _submit(self):
        try:
            cols = list(self.entries.keys())
            vals = [self.entries[c].get().strip() or None for c in cols]
            placeholders = ", ".join(["%s"] * len(cols))
            col_sql = ", ".join([f"`{c}`" for c in cols])
            sql = f"INSERT INTO `{self.table}` ({col_sql}) VALUES ({placeholders})"
            cur = self.conn.cursor()
            cur.execute(sql, vals)
            self.conn.commit()
            cur.close()
            messagebox.showinfo("Inserted", "Row inserted successfully.")
            self.refresh_callback()
            self.destroy()
        except Exception as e:
            try:
                self.conn.rollback()
            except:
                pass
            messagebox.showerror("Insert failed", str(e))


class UpdateWindow(tk.Toplevel):
    def __init__(self, conn, table, row_values, refresh_callback):
        super().__init__()
        self.conn = conn
        self.table = table
        self.row_values = row_values
        self.refresh_callback = refresh_callback
        self.title(f"Update {table}")
        self.geometry("560x620")
        self.configure(bg="#0a0f14")

        try:
            cur = self.conn.cursor()
            cur.execute(f"DESCRIBE `{table}`")
            cols = cur.fetchall()
            cur.close()
        except Exception as e:
            messagebox.showerror("Error", f"Cannot describe table: {e}")
            self.destroy()
            return

        self.cols = cols
        # create a mapping of column order -> col name (DESCRIBE order)
        col_names = [c[0] for c in cols]
        self.entries = {}
        frame = ttk.Frame(self)
        frame.pack(padx=8, pady=8, fill='both', expand=True)
        canvas = tk.Canvas(frame, bg="#0a0f14")
        canvas.pack(side='left', fill='both', expand=True)
        scroll = ttk.Scrollbar(frame, orient="vertical", command=canvas.yview)
        scroll.pack(side='right', fill='y')
        canvas.configure(yscrollcommand=scroll.set)
        inner = ttk.Frame(canvas)
        canvas.create_window((0,0), window=inner, anchor='nw')

        r = 0
        for idx, col in enumerate(cols):
            fname = col[0]
            fextra = col[5]
            ttk.Label(inner, text=fname, width=28).grid(row=r, column=0, sticky='w', padx=6, pady=4)
            ent = ttk.Entry(inner, width=44)
            # populate from row_values using position: row_values align with tree column order.
            try:
                ent_val = row_values[idx] if idx < len(row_values) else ""
            except Exception:
                ent_val = ""
            ent.insert(0, "" if ent_val is None else str(ent_val))
            ent.grid(row=r, column=1, padx=6, pady=4)
            # Make PK (Key) columns read-only
            if col[3] == 'PRI' or (fextra and 'auto_increment' in fextra.lower()):
                ent.configure(state='readonly')
            self.entries[fname] = ent
            r += 1

        inner.update_idletasks()
        canvas.config(scrollregion=canvas.bbox("all"))

        ttk.Button(self, text="Update", command=self._submit).pack(pady=8)

    def _submit(self):
        try:
            # Build update statement excluding read-only PK columns
            # Find primary key columns
            cur = self.conn.cursor()
            cur.execute(f"SHOW KEYS FROM `{self.table}` WHERE Key_name = 'PRIMARY'")
            pk_rows = cur.fetchall()
            pk_cols = [r[4] for r in pk_rows] if pk_rows else []
            cur.close()

            # columns to set: those with state != readonly
            set_cols = []
            params = []
            pk_params = []

            # DESCRIBE gives order - we'll use entries order
            for col in self.cols:
                name = col[0]
                ent = self.entries[name]
                # detect if readonly (PK or auto)
                state = ent.cget('state')
                if state == 'readonly':
                    # this is PK value for WHERE clause
                    pk_params.append(ent.get())
                else:
                    set_cols.append(name)
                    params.append(ent.get() or None)

            if not pk_cols:
                messagebox.showwarning("No PK", "Table has no primary key defined; update not supported.")
                return

            if len(pk_cols) != len(pk_params):
                # fallback: derive pk params by looking up col positions in DESCRIBE
                # This tries to pair pk_cols with their values via entries
                pk_params = []
                for pk in pk_cols:
                    pk_params.append(self.entries[pk].get())

            # build SQL
            set_sql = ", ".join([f"`{c}` = %s" for c in set_cols])
            where_sql = " AND ".join([f"`{c}` = %s" for c in pk_cols])
            sql = f"UPDATE `{self.table}` SET {set_sql} WHERE {where_sql}"
            cur = self.conn.cursor()
            cur.execute(sql, params + pk_params)
            self.conn.commit()
            cur.close()
            messagebox.showinfo("Updated", "Row updated.")
            self.refresh_callback()
            self.destroy()
        except Exception as e:
            try:
                self.conn.rollback()
            except:
                pass
            messagebox.showerror("Update failed", str(e))


# ---------- Procedure / Function windows ----------
class AllocateWindow(tk.Toplevel):
    def __init__(self, conn, refresh_callback):
        super().__init__()
        self.conn = conn
        self.refresh = refresh_callback
        self.title("Call sp_allocate_supply")
        self.geometry("420x180")
        frm = ttk.Frame(self, padding=10)
        frm.pack(fill='both', expand=True)
        ttk.Label(frm, text="MissionID").grid(row=0,column=0,padx=6,pady=6)
        ttk.Label(frm, text="SupplyID").grid(row=1,column=0,padx=6,pady=6)
        ttk.Label(frm, text="Qty").grid(row=2,column=0,padx=6,pady=6)
        self.e_mid = ttk.Entry(frm); self.e_mid.grid(row=0,column=1,padx=6)
        self.e_sid = ttk.Entry(frm); self.e_sid.grid(row=1,column=1,padx=6)
        self.e_qty = ttk.Entry(frm); self.e_qty.grid(row=2,column=1,padx=6)
        ttk.Button(frm, text="Call", command=self._call).grid(row=3,column=0,columnspan=2,pady=8)

    def _call(self):
        try:
            mid = int(self.e_mid.get().strip())
            sid = int(self.e_sid.get().strip())
            qty = float(self.e_qty.get().strip())
        except Exception:
            messagebox.showerror("Input", "Provide numeric MissionID, SupplyID and numeric Qty")
            return
        try:
            cur = self.conn.cursor()
            cur.callproc('sp_allocate_supply', [mid, sid, qty])
            self.conn.commit()
            cur.close()
            messagebox.showinfo("OK", "sp_allocate_supply executed successfully.")
            self.refresh()
            self.destroy()
        except Exception as e:
            try: self.conn.rollback()
            except: pass
            messagebox.showerror("Procedure error", str(e))


class CreateExperimentWindow(tk.Toplevel):
    def __init__(self, conn, refresh_callback):
        super().__init__()
        self.conn = conn
        self.refresh = refresh_callback
        self.title("Call sp_create_experiment")
        self.geometry("640x220")
        frm = ttk.Frame(self, padding=10)
        frm.pack(fill='both', expand=True)
        lab = ["MissionID","Title","Objective","Category","ModuleID","LeadAstronautID"]
        self.entries = {}
        for i, l in enumerate(lab):
            ttk.Label(frm, text=l).grid(row=i, column=0, padx=6, pady=6, sticky='w')
            e = ttk.Entry(frm, width=60)
            e.grid(row=i, column=1, padx=6, pady=6)
            self.entries[l] = e
        ttk.Button(frm, text="Call sp_create_experiment", command=self._call).grid(row=len(lab), column=0, columnspan=2, pady=8)
        self.lbl_res = ttk.Label(frm, text="New ExperimentID: -")
        self.lbl_res.grid(row=len(lab)+1, column=0, columnspan=2)

    def _call(self):
        try:
            mid = int(self.entries["MissionID"].get().strip())
            title = self.entries["Title"].get().strip()
            obj = self.entries["Objective"].get().strip() or None
            cat = self.entries["Category"].get().strip() or None
            mod = int(self.entries["ModuleID"].get().strip()) if self.entries["ModuleID"].get().strip() else None
            lead = int(self.entries["LeadAstronautID"].get().strip()) if self.entries["LeadAstronautID"].get().strip() else None
        except Exception:
            messagebox.showerror("Input", "Provide valid values")
            return
        try:
            cur = self.conn.cursor()
            # MySQL stored proc with OUT param: call and then SELECT @var
            cur.execute("CALL sp_create_experiment(%s,%s,%s,%s,%s,%s,@outexpid)",
                        (mid, title, obj, cat, mod, lead))
            cur.execute("SELECT @outexpid")
            out = cur.fetchone()
            newid = out[0] if out else None
            self.conn.commit()
            self.lbl_res.config(text=f"New ExperimentID: {newid}")
            cur.close()
            messagebox.showinfo("OK", f"Experiment created: {newid}")
            self.refresh()
            self.destroy()
        except Exception as e:
            try: self.conn.rollback()
            except: pass
            messagebox.showerror("Procedure error", str(e))


class FnMissionWindow(tk.Toplevel):
    def __init__(self, conn):
        super().__init__()
        self.conn = conn
        self.title("fn_mission_duration")
        self.geometry("420x120")
        frm = ttk.Frame(self, padding=10)
        frm.pack(fill='both', expand=True)
        ttk.Label(frm, text="MissionID").grid(row=0,column=0,padx=6,pady=6)
        self.e_mid = ttk.Entry(frm); self.e_mid.grid(row=0,column=1,padx=6)
        ttk.Button(frm, text="Call", command=self._call).grid(row=1,column=0,columnspan=2,pady=8)
        self.lbl = ttk.Label(frm, text="Duration: -")
        self.lbl.grid(row=2,column=0,columnspan=2)

    def _call(self):
        try:
            mid = int(self.e_mid.get().strip())
        except Exception:
            messagebox.showerror("Input", "Provide MissionID")
            return
        try:
            cur = self.conn.cursor()
            cur.execute("SELECT fn_mission_duration(%s)", (mid,))
            r = cur.fetchone()
            cur.close()
            self.lbl.config(text=f"Duration: {r[0]}")
        except Exception as e:
            messagebox.showerror("Function error", str(e))


class FnSupplyWindow(tk.Toplevel):
    def __init__(self, conn):
        super().__init__()
        self.conn = conn
        self.title("fn_remaining_supply")
        self.geometry("420x120")
        frm = ttk.Frame(self, padding=10)
        frm.pack(fill='both', expand=True)
        ttk.Label(frm, text="SupplyID").grid(row=0,column=0,padx=6,pady=6)
        self.e_sid = ttk.Entry(frm); self.e_sid.grid(row=0,column=1,padx=6)
        ttk.Button(frm, text="Call", command=self._call).grid(row=1,column=0,columnspan=2,pady=8)
        self.lbl = ttk.Label(frm, text="Remaining: -")
        self.lbl.grid(row=2,column=0,columnspan=2)

    def _call(self):
        try:
            sid = int(self.e_sid.get().strip())
        except Exception:
            messagebox.showerror("Input", "Provide SupplyID")
            return
        try:
            cur = self.conn.cursor()
            cur.execute("SELECT fn_remaining_supply(%s)", (sid,))
            r = cur.fetchone()
            cur.close()
            self.lbl.config(text=f"Remaining: {r[0]}")
        except Exception as e:
            messagebox.showerror("Function error", str(e))


# ------------------ Run the app ------------------
if __name__ == "__main__":
    # Start app with no pre-specified role -> shows login
    SRSApp()
