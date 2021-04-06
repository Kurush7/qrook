import IQRRepository as rep
from qrookDB.data import QRTable
users = QRTable()


class AuthRepository(rep.QRRepository):
    def __init__(self):
        super().__init__()

    def check_credentials(self, login, password):
        if self.db is None:
            raise Exception('DBAdapter not connected to database')
        users = self.db.users
        user_id = self.db.select(users, users.id).where(login=login, password=password).one()
        return user_id['id']

    def find_existing_user(self, email, login, all=False):
        if self.db is None:
            raise Exception('DBAdapter not connected to database')
        users = self.db.users
        data = self.db.select(users, users.email, users.login) \
            .where(bool='or', login=login, email=email)
        data = data.all() if all else data.one()
        return data

    def register_user(self, name, last_name, email, login, password):
        if self.db is None:
            raise Exception('DBAdapter not connected to database')
        users = self.db.users
        user = self.db.insert(users, users.name, users.surname,
                              users.email, users.login, users.password, auto_commit=True) \
            .values([name, last_name, email, login, password])\
            .returning(users.id, users.name, users.surname).one()
        return user

    def update_user(self, id, login=None, password=None, name=None, last_name=None, email=None, avatar=None):
        users = self.db.users
        data = dict()
        if name: data['name'] = name
        if last_name: data['surname'] = last_name
        if email: data['email'] = email
        if login: data['login'] = login
        if password: data['password'] = password
        if avatar: data['avatar'] = avatar
        if len(data) == 0: return True

        if self.db is None:
            raise Exception('DBAdapter not connected to database')
        ok = self.db.update(users,  auto_commit=True).set(**data).where(id=id).exec()
        return ok

    def get_user_preview(self, user_id):
        if self.db is None:
            raise Exception('DBAdapter not connected to database')
        users = self.db.users
        user = self.db.select(users, users.id, users.name, users.surname, users.avatar)\
            .where(id=user_id).one()
        return user

    def get_user_full(self, user_id):
        if self.db is None:
            raise Exception('DBAdapter not connected to database')
        users = self.db.users
        user = self.db.select(users, users.name, users.surname,
                              users.email, users.login, users.avatar).where(id=user_id).one()
        return user

    def delete_user(self, user_id):
        if self.db is None:
            raise Exception('DBAdapter not connected to database')

        ok = self.db.delete(self.db.users, auto_commit=True).where(id=user_id).exec()
        return ok