import hashlib
import json
import threading
import time
import urllib.request
import urllib.error
import urllib.parse
import email.utils
import re

import customtkinter as ctk
from tkinter import messagebox

# ====== مشروع كروت وشحن - ahmed-hartak ======
DB_URL = "https://ahmed-hartak-default-rtdb.firebaseio.com"
USERS_PATH = "users"
FIREBASE_API_KEY = "AIzaSyBUzyV0L-0e-EW9egYcagSzrP_ke2dcGhg"  # من google-services.json
# ==========================================

def create_firebase_auth_user(email, password):
    """ينشئ المستخدم في Firebase Authentication (يظهر في console.firebase.google.com/project/ahmed-hartak/authentication/users)"""
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
    body = json.dumps({"email": email, "password": password, "returnSecureToken": True}).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return True, data.get("localId", "")
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")
        try:
            j = json.loads(err_body)
            msg = j.get("error", {}).get("message", err_body)
        except:
            msg = err_body
        if "EMAIL_EXISTS" in msg:
            return False, "البريد موجود بالفعل في Authentication"
        if "WEAK_PASSWORD" in msg:
            return False, "كلمة السر ضعيفة (6 أحرف على الأقل)"
        if "INVALID_EMAIL" in msg:
            return False, "البريد غير صحيح"
        return False, f"Auth error: {msg}"
    except Exception as ex:
        return False, f"Auth error: {str(ex)}"

def delete_firebase_auth_user_note():
    return "ملاحظة: حذف Authentication يحتاج حذف يدوي من الكونسول أو Admin SDK"

def encode_email(email):
    # Firebase لا يسمح بـ . في المفاتيح -> نستبدل . بـ ,
    return email.strip().lower().replace('.', ',')

def decode_email(key):
    return key.replace(',', '.')

def is_valid_email(email):
    return bool(re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email.strip()))

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


def register_user(email, password, days, hours, minutes):
    if not is_valid_email(email):
        return False, "البريد الإلكتروني غير صحيح"
    # 1) إنشاء في Authentication أولاً (يظهر في https://console.firebase.google.com/project/ahmed-hartak/authentication/users)
    ok_auth, msg_auth = create_firebase_auth_user(email.strip().lower(), password)
    if not ok_auth:
        return False, msg_auth
    # 2) إنشاء في Realtime Database مع تاريخ الانتهاء
    total_seconds = days * 86400 + hours * 3600 + minutes * 60
    now = get_google_timestamp()
    data = {"email": email.strip().lower(), "password": hash_password(password), "created": now, "expires": now + total_seconds, "authUid": msg_auth}
    key = encode_email(email)
    url = f"{DB_URL}/{USERS_PATH}/{urllib.parse.quote(key, safe=',')}.json"
    body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="PUT")
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "تم إنشاء الحساب في Authentication و Database بنجاح!"
    except urllib.error.HTTPError as e:
        return False, f"تم إنشاؤه في Auth لكن فشل Database ({e.code}). احذفه من Authentication يدوياً"
    except Exception:
        return False, "تم إنشاؤه في Auth لكن تعذر الاتصال بـ Database"


def renew_user(email, days, hours, minutes):
    users = get_all_users()
    if users is None:
        return False, "Could not connect to the database."
    key = encode_email(email)
    user = users.get(key)
    if user is None:
        # جرب البحث بالإيميل الأصلي للتوافق مع الحسابات القديمة بالـ username
        user = users.get(email.strip())
        if user is not None:
            key = email.strip()
        else:
            return False, "البريد غير موجود"

    now = get_google_timestamp()
    extra = days * 86400 + hours * 3600 + minutes * 60
    if isinstance(user, dict):
        current_expires = user.get("expires")
    else:
        user = {"password": user, "email": email.strip().lower()}
        current_expires = None
    base = max(now, current_expires or now)
    user["expires"] = base + extra
    if "email" not in user:
        user["email"] = email.strip().lower()

    url = f"{DB_URL}/{USERS_PATH}/{urllib.parse.quote(key, safe=',')}.json"
    req = urllib.request.Request(
        url, data=json.dumps(user).encode("utf-8"), method="PUT"
    )
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "تم تمديد الاشتراك بنجاح!"
    except urllib.error.HTTPError as e:
        return False, f"Server error ({e.code}). Check the write rules."
    except Exception:
        return False, "Could not connect to the database."


def change_password(email, new_password):
    users = get_all_users()
    if users is None:
        return False, "Could not connect to the database."
    key = encode_email(email)
    user = users.get(key)
    if user is None:
        user = users.get(email.strip())
        if user is not None:
            key = email.strip()
        else:
            return False, "البريد غير موجود"

    if isinstance(user, dict):
        user["password"] = hash_password(new_password)
    else:
        user = {"password": hash_password(new_password), "email": email.strip().lower()}
    if "email" not in user:
        user["email"] = email.strip().lower()

    url = f"{DB_URL}/{USERS_PATH}/{urllib.parse.quote(key, safe=',')}.json"
    req = urllib.request.Request(
        url, data=json.dumps(user).encode("utf-8"), method="PUT"
    )
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "تم تغيير كلمة السر بنجاح!"
    except urllib.error.HTTPError as e:
        return False, f"Server error ({e.code}). Check the write rules."
    except Exception:
        return False, "Could not connect to the database."


def delete_user(email):
    key = encode_email(email)
    users = get_all_users()
    actual_key = key
    if users is not None and key not in users and email.strip() in users:
        actual_key = email.strip()
    url = f"{DB_URL}/{USERS_PATH}/{urllib.parse.quote(actual_key, safe=',')}.json"
    req = urllib.request.Request(url, method="DELETE")
    try:
        urllib.request.urlopen(req, timeout=15)
        return True, "تم حذفه من Database. احذفه يدوياً من Authentication: console.firebase.google.com/project/ahmed-hartak/authentication/users"
    except urllib.error.HTTPError as e:
        return False, f"Server error ({e.code}). Check the write rules."
    except Exception:
        return False, "Could not connect to the database."


class UserPopup(ctk.CTkToplevel):
    def __init__(self, master, email_key, on_change=None):
        super().__init__(master)
        # email_key هو المفتاح المشفر في Firebase
        self.email_key = email_key
        self.email_display = decode_email(email_key) if ',' in email_key else email_key
        # لو كان username قديم بدون @، اعرضه كما هو
        if '@' not in self.email_display:
            self.email_display = email_key
        self.on_change = on_change
        self.title(f"User: {self.email_display}")
        self.geometry("360x460")
        self.resizable(False, False)

        container = ctk.CTkFrame(self)
        container.pack(fill="both", expand=True, padx=16, pady=16)

        ctk.CTkLabel(
            container, text=self.email_display, font=("Arial", 14, "bold"), wraplength=320
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
            ok, msg = change_password(self.email_display, new)
        self.after(0, lambda: self._set_msg(self.pw_msg, msg, ok))
        self.after(0, lambda: self.btn_pw.configure(state="normal"))

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
                ok, msg = renew_user(self.email_display, d, h, m)
        self.after(0, lambda: self._set_msg(self.ext_msg, msg, ok))
        self.after(0, lambda: self.btn_extend.configure(state="normal"))
        if ok and self.on_change:
            self.after(0, self.on_change)

    def _start_delete(self):
        if not messagebox.askyesno(
            "Confirm Delete", f"Delete user '{self.email_display}'?"
        ):
            return
        self._set_msg(self.del_msg, "Loading...")
        self.btn_delete.configure(state="disabled")
        threading.Thread(target=self._delete_worker, daemon=True).start()

    def _delete_worker(self):
        ok, msg = delete_user(self.email_display)
        self.after(0, lambda: self._set_msg(self.del_msg, msg, ok))
        self.after(0, lambda: self.btn_delete.configure(state="normal"))
        if ok:
            if self.on_change:
                self.after(0, self.on_change)
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

        self.c_email = self._entry_row(
            self.tab_create, 1, "Email", None, plc="example@mail.com"
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

        self.e_email = self._entry_row(
            self.tab_extend, 1, "Email", None, plc="user@mail.com"
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
            self.tab_users, text="Users (Email)", font=("Arial", 22, "bold")
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
        email = self.c_email.get().strip().lower()
        password = self.c_pass.get()
        confirm = self.c_confirm.get()

        if not email or not password:
            msg, ok = "Please enter email and password.", False
        elif not is_valid_email(email):
            msg, ok = "البريد غير صحيح", False
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
                elif encode_email(email) in users or email in users:
                    msg, ok = "Email already exists.", False
                else:
                    ok, msg = register_user(email, password, *time_val)

        self.after(0, lambda: self._set_message(self.c_msg, msg, ok))
        self.after(0, lambda: self.btn_create.configure(state="normal"))

    def _start_extend(self):
        self._set_message(self.e_msg, "Loading...")
        self.btn_extend.configure(state="disabled")
        threading.Thread(target=self._extend_worker, daemon=True).start()

    def _extend_worker(self):
        email = self.e_email.get().strip().lower()
        if not email:
            msg, ok = "Please enter an email.", False
        elif not is_valid_email(email):
            msg, ok = "البريد غير صحيح", False
        else:
            time_val, err = self._read_time(self.e_days, self.e_hours, self.e_minutes)
            if err:
                msg, ok = err, False
            else:
                ok, msg = renew_user(email, *time_val)

        self.after(0, lambda: self._set_message(self.e_msg, msg, ok))
        self.after(0, lambda: self.btn_extend.configure(state="normal"))

    def _refresh_users(self):
        threading.Thread(target=self._refresh_worker, daemon=True).start()

    def _refresh_worker(self):
        users = get_all_users()
        self.after(0, lambda: self._render_users(users))

    def _render_users(self, users):
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
            for key, user in users.items():
                # decode email for display
                display_email = decode_email(key) if ',' in key or '@' in key else key
                if isinstance(user, dict) and 'email' in user:
                    display_email = user.get('email', display_email)
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
                    text=f"{display_email}  |  {status}",
                    anchor="w",
                    command=lambda k=key: self._open_user_popup(k),
                )
                btn.pack(fill="x", padx=5, pady=3)

    def _open_user_popup(self, email_key):
        UserPopup(self, email_key, on_change=self._refresh_users)


if __name__ == "__main__":
    app = AdminApp()
    app.mainloop()
