import hashlib
import json
import threading
import time
import urllib.request
import urllib.error
import email.utils

import customtkinter as ctk
from tkinter import messagebox

# ====== مشروع كروت وشحن - ahmed-hartak ======
DB_URL = "https://ahmed-hartak-default-rtdb.firebaseio.com"
USERS_PATH = "users"
# ==========================================


def hash_password(password):
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def get_google_timestamp():
    try:
        req = urllib.request.Request("https://www.google.com", method="HEAD")
        with urllib.request.urlopen(req, timeout=10) as resp:
            date_str = resp.headers.get("Date")
        return int(email.utils.parsedate_to_datetime(date_str).timestamp())
    except Exception:
        return int(time.time())


def get_all_users():
    url = f"{DB_URL}/{USERS_PATH}.json"
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        return data or {}
    except Exception:
        return None


def register_user(username, password, days, hours, minutes):
    total_seconds = days * 86400 + hours * 3600 + minutes * 60
    now = get_google_timestamp()
    data = {"password": hash_password(password), "created": now, "expires": now + total_seconds}
    url = f"{DB_URL}/{USERS_PATH}/{username}.json"
    body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="PUT")
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "Account created successfully!"
    except urllib.error.HTTPError as e:
        return False, f"Server error ({e.code}). Check the write rules."
    except Exception:
        return False, "Could not connect to the database."


def renew_user(username, days, hours, minutes):
    users = get_all_users()
    if users is None:
        return False, "Could not connect to the database."
    user = users.get(username)
    if user is None:
        return False, "Username does not exist."

    now = get_google_timestamp()
    extra = days * 86400 + hours * 3600 + minutes * 60
    if isinstance(user, dict):
        current_expires = user.get("expires")
    else:
        user = {"password": user}
        current_expires = None
    base = max(now, current_expires or now)
    user["expires"] = base + extra

    url = f"{DB_URL}/{USERS_PATH}/{username}.json"
    req = urllib.request.Request(
        url, data=json.dumps(user).encode("utf-8"), method="PUT"
    )
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "Subscription extended successfully!"
    except urllib.error.HTTPError as e:
        return False, f"Server error ({e.code}). Check the write rules."
    except Exception:
        return False, "Could not connect to the database."


def change_password(username, new_password):
    users = get_all_users()
    if users is None:
        return False, "Could not connect to the database."
    user = users.get(username)
    if user is None:
        return False, "Username does not exist."

    if isinstance(user, dict):
        user["password"] = hash_password(new_password)
    else:
        user = {"password": hash_password(new_password)}

    url = f"{DB_URL}/{USERS_PATH}/{username}.json"
    req = urllib.request.Request(
        url, data=json.dumps(user).encode("utf-8"), method="PUT"
    )
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "Password changed successfully!"
    except urllib.error.HTTPError as e:
        return False, f"Server error ({e.code}). Check the write rules."
    except Exception:
        return False, "Could not connect to the database."


def delete_user(username):
    url = f"{DB_URL}/{USERS_PATH}/{username}.json"
    req = urllib.request.Request(url, method="DELETE")
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "User deleted successfully!"
    except urllib.error.HTTPError as e:
        return False, f"Server error ({e.code}). Check the write rules."
    except Exception:
        return False, "Could not connect to the database."


class UserPopup(ctk.CTkToplevel):
    def __init__(self, master, username, on_change=None):
        super().__init__(master)
        self.username = username
        self.on_change = on_change
        self.title(f"User: {username}")
        self.geometry("360x460")
        self.resizable(False, False)

        container = ctk.CTkFrame(self)
        container.pack(fill="both", expand=True, padx=16, pady=16)

        ctk.CTkLabel(
            container, text=username, font=("Arial", 20, "bold")
        ).pack(pady=(0, 12))

        ctk.CTkLabel(
            container, text="Change Password", font=("Arial", 15, "bold")
        ).pack(pady=(6, 2))

        self.pw_new = ctk.CTkEntry(container, placeholder_text="New password", show="\u2022")
        self.pw_new.pack(fill="x", padx=8, pady=4)
        self.pw_confirm = ctk.CTkEntry(container, placeholder_text="Confirm password", show="\u2022")
        self.pw_confirm.pack(fill="x", padx=8, pady=4)

        self.btn_pw = ctk.CTkButton(container, text="Save Password", command=self._start_pw_change)
        self.btn_pw.pack(fill="x", padx=8, pady=(6, 2))
        self.pw_msg = ctk.CTkLabel(container, text="", font=("Arial", 12))
        self.pw_msg.pack()

        ctk.CTkLabel(
            container, text="Add Extra Time", font=("Arial", 15, "bold")
        ).pack(pady=(12, 2))

        time_row = ctk.CTkFrame(container, fg_color="transparent")
        time_row.pack(fill="x", padx=8)
        time_row.grid_columnconfigure(0, weight=1)
        time_row.grid_columnconfigure(1, weight=1)
        time_row.grid_columnconfigure(2, weight=1)

        self.x_days = ctk.CTkEntry(time_row, placeholder_text="Days",
                                   textvariable=ctk.StringVar(value="0"))
        self.x_days.grid(row=0, column=0, sticky="ew", padx=2)
        self.x_hours = ctk.CTkEntry(time_row, placeholder_text="Hours",
                                    textvariable=ctk.StringVar(value="0"))
        self.x_hours.grid(row=0, column=1, sticky="ew", padx=2)
        self.x_minutes = ctk.CTkEntry(time_row, placeholder_text="Minutes",
                                      textvariable=ctk.StringVar(value="0"))
        self.x_minutes.grid(row=0, column=2, sticky="ew", padx=2)

        self.btn_extend = ctk.CTkButton(container, text="Extend", command=self._start_extend)
        self.btn_extend.pack(fill="x", padx=8, pady=(6, 2))
        self.ext_msg = ctk.CTkLabel(container, text="", font=("Arial", 12))
        self.ext_msg.pack()

        self.btn_delete = ctk.CTkButton(
            container, text="Delete Account", fg_color="#e74c3c",
            hover_color="#c0392b", command=self._start_delete
        )
        self.btn_delete.pack(fill="x", padx=8, pady=(16, 2))
        self.del_msg = ctk.CTkLabel(container, text="", font=("Arial", 12))
        self.del_msg.pack()

    def _set_msg(self, label, text, success=False):
        label.configure(text=text, text_color="#2ecc71" if success else "#e74c3c")

    def _start_pw_change(self):
        self._set_msg(self.pw_msg, "Loading...")
        self.btn_pw.configure(state="disabled")
        threading.Thread(target=self._pw_worker, daemon=True).start()

    def _pw_worker(self):
        new = self.pw_new.get()
        confirm = self.pw_confirm.get()
        if not new:
            msg, ok = "Please enter a new password.", False
        elif new != confirm:
            msg, ok = "Passwords do not match.", False
        else:
            ok, msg = change_password(self.username, new)
        self._set_msg(self.pw_msg, msg, ok)
        self.btn_pw.configure(state="normal")

    def _start_extend(self):
        self._set_msg(self.ext_msg, "Loading...")
        self.btn_extend.configure(state="disabled")
        threading.Thread(target=self._extend_worker, daemon=True).start()

    def _extend_worker(self):
        parts = [
            self.x_days.get().strip(),
            self.x_hours.get().strip(),
            self.x_minutes.get().strip(),
        ]
        if not all(p.isdigit() for p in parts):
            msg, ok = "Time fields must be non-negative integers.", False
        else:
            d, h, m = (int(p) for p in parts)
            if d + h + m <= 0:
                msg, ok = "Extra time must be greater than zero.", False
            else:
                ok, msg = renew_user(self.username, d, h, m)
        self._set_msg(self.ext_msg, msg, ok)
        self.btn_extend.configure(state="normal")
        if ok and self.on_change:
            self.on_change()

    def _start_delete(self):
        if not messagebox.askyesno(
            "Confirm Delete", f"Delete user '{self.username}'?"
        ):
            return
        self._set_msg(self.del_msg, "Loading...")
        self.btn_delete.configure(state="disabled")
        threading.Thread(target=self._delete_worker, daemon=True).start()

    def _delete_worker(self):
        ok, msg = delete_user(self.username)
        self._set_msg(self.del_msg, msg, ok)
        self.btn_delete.configure(state="normal")
        if ok:
            if self.on_change:
                self.on_change()
            self.after(800, self.destroy)


class AdminApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("كروت وشحن - Admin Panel | ahmed-hartak")
        self.geometry("430x520")
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")

        self.tabview = ctk.CTkTabview(self, width=390, height=470)
        self.tabview.pack(pady=20, padx=20, fill="both", expand=True)

        self.tab_create = self.tabview.add("Create Account")
        self.tab_extend = self.tabview.add("Extend Time")
        self.tab_users = self.tabview.add("Users")
        self._build_create_tab()
        self._build_extend_tab()
        self._build_users_tab()

    def _grid(self, tab):
        pad = 20
        for i in range(6):
            tab.grid_columnconfigure(i, weight=1)
        return pad

    def _entry_row(self, tab, row, label_text, var, show=None, plc="0"):
        ctk.CTkLabel(tab, text=label_text, font=("Arial", 13)).grid(
            row=row, column=0, sticky="w", padx=20
        )
        if var:
            e = ctk.CTkEntry(tab, textvariable=var)
        else:
            e = ctk.CTkEntry(tab)
        e.grid(row=row + 1, column=0, columnspan=6, sticky="ew", padx=20, pady=(0, 10))
        return e

    def _build_create_tab(self):
        self._grid(self.tab_create)

        ctk.CTkLabel(
            self.tab_create, text="Create Account", font=("Arial", 22, "bold")
        ).grid(row=0, column=0, columnspan=6, pady=(20, 15))

        self.c_user = self._entry_row(
            self.tab_create, 1, "Username", None, plc="Choose username"
        )
        self.c_pass = self._entry_row(
            self.tab_create, 3, "Password", None, show="\u2022", plc="Choose password"
        )
        self.c_confirm = self._entry_row(
            self.tab_create, 5, "Confirm Password", None, show="\u2022", plc="Repeat password"
        )

        ctk.CTkLabel(self.tab_create, text="Validity", font=("Arial", 13)).grid(
            row=7, column=0, sticky="w", padx=20
        )
        ctk.CTkLabel(self.tab_create, text="Days", font=("Arial", 11)).grid(row=8, column=0)
        ctk.CTkLabel(self.tab_create, text="Hours", font=("Arial", 11)).grid(row=8, column=1)
        ctk.CTkLabel(self.tab_create, text="Minutes", font=("Arial", 11)).grid(row=8, column=2)

        self.c_days = ctk.CTkEntry(
            self.tab_create, textvariable=ctk.StringVar(value="30")
        )
        self.c_days.grid(row=9, column=0, sticky="ew", padx=(20, 5), pady=(0, 10))

        self.c_hours = ctk.CTkEntry(
            self.tab_create, textvariable=ctk.StringVar(value="0")
        )
        self.c_hours.grid(row=9, column=1, sticky="ew", padx=5, pady=(0, 10))

        self.c_minutes = ctk.CTkEntry(
            self.tab_create, textvariable=ctk.StringVar(value="0")
        )
        self.c_minutes.grid(row=9, column=2, sticky="ew", padx=(5, 20), pady=(0, 10))

        self.btn_create = ctk.CTkButton(
            self.tab_create, text="Create Account", command=self._start_create
        )
        self.btn_create.grid(
            row=10, column=0, columnspan=6, sticky="ew", padx=20, pady=(10, 5)
        )

        self.c_msg = ctk.CTkLabel(self.tab_create, text="", font=("Arial", 13))
        self.c_msg.grid(row=11, column=0, columnspan=6, pady=5)

    def _build_extend_tab(self):
        self._grid(self.tab_extend)

        ctk.CTkLabel(
            self.tab_extend, text="Extend Time", font=("Arial", 22, "bold")
        ).grid(row=0, column=0, columnspan=6, pady=(20, 15))

        self.e_user = self._entry_row(
            self.tab_extend, 1, "Username", None, plc="Existing username"
        )

        ctk.CTkLabel(self.tab_extend, text="Extra Time", font=("Arial", 13)).grid(
            row=3, column=0, sticky="w", padx=20
        )
        ctk.CTkLabel(self.tab_extend, text="Days", font=("Arial", 11)).grid(row=4, column=0)
        ctk.CTkLabel(self.tab_extend, text="Hours", font=("Arial", 11)).grid(row=4, column=1)
        ctk.CTkLabel(self.tab_extend, text="Minutes", font=("Arial", 11)).grid(row=4, column=2)

        self.e_days = ctk.CTkEntry(
            self.tab_extend, textvariable=ctk.StringVar(value="0")
        )
        self.e_days.grid(row=5, column=0, sticky="ew", padx=(20, 5), pady=(0, 10))

        self.e_hours = ctk.CTkEntry(
            self.tab_extend, textvariable=ctk.StringVar(value="0")
        )
        self.e_hours.grid(row=5, column=1, sticky="ew", padx=5, pady=(0, 10))

        self.e_minutes = ctk.CTkEntry(
            self.tab_extend, textvariable=ctk.StringVar(value="0")
        )
        self.e_minutes.grid(row=5, column=2, sticky="ew", padx=(5, 20), pady=(0, 10))

        self.btn_extend = ctk.CTkButton(
            self.tab_extend, text="Extend", command=self._start_extend
        )
        self.btn_extend.grid(
            row=6, column=0, columnspan=6, sticky="ew", padx=20, pady=(10, 5)
        )

        self.e_msg = ctk.CTkLabel(self.tab_extend, text="", font=("Arial", 13))
        self.e_msg.grid(row=7, column=0, columnspan=6, pady=5)

    def _build_users_tab(self):
        self._grid(self.tab_users)
        self.tab_users.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(
            self.tab_users, text="Users", font=("Arial", 22, "bold")
        ).grid(row=0, column=0, columnspan=6, pady=(20, 15))

        self.users_frame = ctk.CTkScrollableFrame(
            self.tab_users, width=340, height=280
        )
        self.users_frame.grid(
            row=1, column=0, columnspan=6, padx=20, pady=(0, 10), sticky="nsew"
        )
        self.users_frame.grid_columnconfigure(0, weight=1)

        self.btn_refresh = ctk.CTkButton(
            self.tab_users, text="Refresh", command=self._refresh_users
        )
        self.btn_refresh.grid(
            row=2, column=0, columnspan=6, sticky="ew", padx=20, pady=(10, 5)
        )

    def _set_message(self, label, text, success=False):
        label.configure(
            text=text, text_color="#2ecc71" if success else "#e74c3c"
        )

    def _read_time(self, days_var, hours_var, minutes_var):
        parts = [days_var.get().strip(), hours_var.get().strip(), minutes_var.get().strip()]
        if not all(p.isdigit() for p in parts):
            return None, "Validity fields must be non-negative integers."
        d, h, m = (int(p) for p in parts)
        if d + h + m <= 0:
            return None, "Validity must be greater than zero."
        return (d, h, m), ""

    def _start_create(self):
        self._set_message(self.c_msg, "Loading...")
        self.btn_create.configure(state="disabled")
        threading.Thread(target=self._create_worker, daemon=True).start()

    def _create_worker(self):
        username = self.c_user.get().strip()
        password = self.c_pass.get()
        confirm = self.c_confirm.get()

        if not username or not password:
            msg, ok = "Please enter username and password.", False
        elif password != confirm:
            msg, ok = "Passwords do not match.", False
        else:
            time_val, err = self._read_time(self.c_days, self.c_hours, self.c_minutes)
            if err:
                msg, ok = err, False
            else:
                users = get_all_users()
                if users is None:
                    msg, ok = "Could not connect to the database.", False
                elif username in users:
                    msg, ok = "Username already exists.", False
                else:
                    ok, msg = register_user(username, password, *time_val)

        self._set_message(self.c_msg, msg, ok)
        self.btn_create.configure(state="normal")

    def _start_extend(self):
        self._set_message(self.e_msg, "Loading...")
        self.btn_extend.configure(state="disabled")
        threading.Thread(target=self._extend_worker, daemon=True).start()

    def _extend_worker(self):
        username = self.e_user.get().strip()
        if not username:
            msg, ok = "Please enter a username.", False
        else:
            time_val, err = self._read_time(self.e_days, self.e_hours, self.e_minutes)
            if err:
                msg, ok = err, False
            else:
                ok, msg = renew_user(username, *time_val)

        self._set_message(self.e_msg, msg, ok)
        self.btn_extend.configure(state="normal")

    def _refresh_users(self):
        threading.Thread(target=self._refresh_worker, daemon=True).start()

    def _refresh_worker(self):
        users = get_all_users()
        self.users_frame._parent_canvas.yview_moveto(0.0)
        for widget in self.users_frame.winfo_children():
            widget.destroy()

        if users is None:
            ctk.CTkLabel(
                self.users_frame, text="Could not connect to the database.", fg_color="transparent"
            ).pack(pady=10)
        elif not users:
            ctk.CTkLabel(
                self.users_frame, text="No accounts yet.", fg_color="transparent"
            ).pack(pady=10)
        else:
            now = get_google_timestamp()
            for name, user in users.items():
                expires = user.get("expires") if isinstance(user, dict) else None
                if expires is None:
                    status = "no expiry"
                elif expires > now:
                    days_left = (expires - now) / 86400
                    status = f"active ({days_left:.1f} days left)"
                else:
                    status = "EXPIRED"

                btn = ctk.CTkButton(
                    self.users_frame,
                    text=f"{name}  |  {status}",
                    anchor="w",
                    command=lambda n=name: self._open_user_popup(n),
                )
                btn.grid(row=len(self.users_frame.winfo_children()), column=0,
                         sticky="ew", padx=5, pady=3)

    def _open_user_popup(self, username):
        UserPopup(self, username, on_change=self._refresh_users)


if __name__ == "__main__":
    app = AdminApp()
    app.mainloop()