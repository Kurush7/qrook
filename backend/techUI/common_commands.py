from common.IQRRepository import IQRRepository
from common.IQRServer import QRContext

def create_context(json_data=dict(), params=dict(), headers=dict(), form=dict(), files=dict(),
                   repository=IQRRepository(), managers=None):
    if managers is None: managers = []
    ctx = QRContext(json_data, params, headers, form, files, repository=repository)
    for m in managers:
        ctx.add_manager(m.get_name(), m)
    return ctx