"""Stock photos for the demo accounts that seed_hosts creates.

Hand-picked from Unsplash (free to use, https://unsplash.com/license):
portraits split by gender so each face matches the demo first name, and
scenes per meeting category for the host galleries. They're downloaded once
into MEDIA_ROOT/demo/ (git-ignored) and shared by every demo account; real
accounts are never touched.
"""
import random
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path
from urllib.request import urlopen

from django.conf import settings
from django.db import transaction

from accounts.models import User

from .categories import normalize_categories
from .demo import FEMALE_NAMES, MALE_NAMES, SEED_PREFIX
from .models import HostProfile, ProfilePhoto

FEMALE_PORTRAITS = [
    '1494790108377-be9c29b29330', '1438761681033-6461ffad8d80', '1524504388940-b1c1722653e1',
    '1534528741775-53994a69daeb', '1573496359142-b8d87734a5a2', '1544005313-94ddf0286df2',
    '1554151228-14d9def656e4', '1580489944761-15a19d654956', '1607746882042-944635dfe10e',
    '1531123897727-8f129e1688ce', '1541101767792-f9b2b1c4f127', '1548142813-c348350df52b',
    '1487412720507-e7ab37603c6f', '1508214751196-bcfd4ca60f91', '1529626455594-4ff0802cfb7e',
    '1551836022-d5d88e9218df', '1567532939604-b6b5b0db2604', '1619895862022-09114b41f16f',
    '1544725176-7c40e5a71c5e', '1535295972055-1c762f4483e5', '1546539782-6fc531453083',
    '1488426862026-3ee34a7d66df', '1489424731084-a5d8b219a5bb', '1499952127939-9bbf5af6c51c',
    '1502685104226-ee32379fefbe', '1509967419530-da38b4704bc6', '1517365830460-955ce3ccd263',
    '1520813792240-56fc4a3765a7', '1525134479668-1bee5c7c6845', '1542206395-9feb3edaa68d',
    '1549351236-caca0f174515', '1550525811-e5869dd03032', '1557296387-5358ad7997bb',
    '1558898479-33c0057a5d12', '1569913486515-b74bf7751574', '1573497019940-1c28c88b4f3e',
    '1574701148212-8518049c7b2c', '1579591919791-0e3737ae3808', '1588516903720-8ceb67f9ef84',
    '1592621385612-4d7129426394', '1598550874175-4d0ef436c909', '1604004555489-723a93d6ce74',
    '1614644147724-2d4785d69962', '1493666438817-866a91353ca9', '1554384645-13eab165c24b',
]
MALE_PORTRAITS = [
    '1500648767791-00dcc994a43e', '1506794778202-cad84cf45f1d', '1507003211169-0a1dd7228f2d',
    '1539571696357-5a69c17a67c6', '1547425260-76bcadfb4f2c', '1552058544-f2b08422138a',
    '1557862921-37829c790f19', '1560250097-0b93528c311a', '1599566150163-29194dcaad36',
    '1633332755192-727a05c4013d', '1535713875002-d1d0cf377fde', '1504257432389-52343af06ae3',
    '1527980965255-d3b416303d12', '1531427186611-ecfd6d936c79', '1542909168-82c3e7fdca5c',
    '1570295999919-56ceb5ecca61', '1595152772835-219674b2a8a6', '1492562080023-ab3db95bfbce',
    '1463453091185-61582044d556', '1472099645785-5658abf4ff4e', '1480429370139-e0132c086e2a',
    '1489980557514-251d61e3eeb6', '1503443207922-dff7d543fd0e', '1505503693641-1926193e8d57',
    '1513152697235-fe74c283646a', '1520341280432-4749d4d7bcf9', '1521572267360-ee0c2909d518',
    '1528892952291-009c663ce843', '1530268729831-4b0b9e170218', '1533227268428-f9ed0900fb3b',
    '1537511446984-935f663eb1f4', '1541647376583-8934aaf3448a', '1544168190-79c17527004f',
    '1545167622-3a6ac756afa4', '1563237023-b1e970526dcb', '1566492031773-4f4e44671857',
    '1568602471122-7832951cc4c5', '1590086782957-93c06ef21604', '1615109398623-88346a601842',
    '1545996124-0501ebae84d0', '1601455763557-db1bea8a9a5a', '1540569014015-19a7be504e3a',
    '1559548331-f9cb98001426', '1564564321837-a57b7070ac4f', '1610216705422-caa3fcb6d158',
]
SCENES = {
    'coffee': [
        '1495474472287-4d71bcdd2085', '1509042239860-f550ce710b93', '1501339847302-ac426a4a7cbb',
        '1442512595331-e89e73853f31', '1453614512568-c4024d13c247', '1511920170033-f8396924c348',
        '1554118811-1e0d58224f24', '1521017432531-fbd92d768814', '1447933601403-0c6688de566e',
        '1461023058943-07fcbe16d735', '1497935586351-b67a49e012bf', '1498804103079-a6351b050096',
        '1507133750040-4a8f57021571', '1514432324607-a09d9b4aefdd', '1517701550927-30cf4ba1dba5',
        '1525610553991-2bede1a236e2', '1559925393-8be0ec4767c8', '1559496417-e7f25cb247f3',
        '1541167760496-1628856ab772', '1600093463592-8e36ae95ef56',
    ],
    'networking': [
        '1515187029135-18ee286d815b', '1528605248644-14dd04022da1', '1540575467063-178a50c2df87',
        '1556761175-b413da4baf72', '1505373877841-8d25f7d46678', '1475721027785-f74eccf877e2',
        '1543269865-cbf427effbad', '1531058020387-3be344556be6', '1556761175-5973dc0f32e7',
        '1557804506-669a67965ba0', '1561489396-888724a1543d', '1591115765373-5207764f72e7',
        '1600880292203-757bb62b4baf', '1515169067868-5387ec356754',
    ],
    'mentorship': [
        '1552664730-d307ca884978', '1517245386807-bb43f82c33c4', '1600880292089-90a7e086ee0c',
        '1542744173-8e7e53415bb0', '1519389950473-47ba0277781c', '1531545514256-b1400bc00f31',
        '1521791136064-7986c2920216', '1556761175-4b46a572b786', '1498050108023-c5249f4df085',
        '1454165804606-c3d57bc86b40', '1504384308090-c894fdcc538d', '1522202176988-66273c2fd55f',
    ],
    'language': [
        '1456513080510-7bf3a84b82f8', '1503676260728-1c00da094a0b', '1513475382585-d06e58bcb0e0',
        '1488190211105-8b0e65b80b4e', '1434030216411-0b793f4b4173', '1481627834876-b7833e8f5570',
        '1497633762265-9d179a990aa6', '1524995997946-a1c2e315a42f', '1544716278-ca5e3f4abd8c',
        '1550399105-c4db5fb85c18', '1516979187457-637abb4f9353', '1427504494785-3a9ca7044f45',
    ],
    'travel': [
        '1483729558449-99ef09a8c325', '1516306580123-e6e52b1b7b5f', '1543059080-f9b1272213d5',
        '1554168848-228452c09d60', '1544989164-31dc3c645987', '1469854523086-cc02fe5d8800',
        '1476514525535-07fb3b4ae5f1', '1488646953014-85cb44e25828', '1507525428034-b723cf961d3e',
        '1501785888041-af3ef285b470', '1500835556837-99ac94a94552', '1527631746610-bca00a040d60',
        '1503220317375-aaad61436b1b', '1504150558240-0b4fd8946624', '1551632811-561732d1e306',
        '1564659907532-6b5f98c8e70f', '1548963670-aaaa8f73a5e3', '1589909202802-8f4aadce1849',
    ],
    'social': [
        '1529156069898-49953e39b3ac', '1511632765486-a01980e01a18', '1492684223066-81342ee5ff30',
        '1514525253161-7a46d19cd819', '1528605105345-5344ea20e269', '1543007630-9710e4a00a20',
        '1470225620780-dba8ba36b745', '1506157786151-b8491531f063', '1516450360452-9312f5e86fc7',
        '1533174072545-7a4b6ad7a6c3', '1541532713592-79a0317b6b77', '1555396273-367ea4eb4db5',
        '1559339352-11d035aa65de', '1527529482837-4698179dc6ce',
    ],
    'workout': [
        '1534438327276-14e5300c3a48', '1517836357463-d25dfeac3438', '1571019613454-1cb2f99b2d8b',
        '1517963879433-6ad2b056d712', '1540497077202-7c8a3999166f', '1518611012118-696072aa579a',
        '1599058917212-d750089bc07e', '1571019614242-c5c5dee9f50b', '1541534741688-6078c6bfb5c5',
        '1549060279-7e168fcee0c2', '1574680096145-d05b474e2155', '1583454110551-21f2fa2afe61',
        '1593079831268-3381b0db4a77', '1517130038641-a774d04afb3c', '1552674605-db6ffd4facb5',
        '1576678927484-cc907957088c', '1594737625785-a6cbdabd333c',
    ],
}

# Scenes per host gallery (the app shows the avatar first, then these).
GALLERY_SIZE = 2
# 4:5 like the app's photo cards; portraits are cropped around the face.
PHOTO_URL = 'https://images.unsplash.com/photo-{id}?fm=jpg&q=80&fit=crop&w=800&h=1000&crop={crop}'


@dataclass
class DemoPhotos:
    """Media-relative paths of the demo photos that are on disk."""
    female: list = field(default_factory=list)
    male: list = field(default_factory=list)
    scenes: dict = field(default_factory=dict)  # category slug -> paths
    missing: int = 0  # photos that couldn't be downloaded


def _fetch(job):
    url, dest = job
    if dest.exists():
        return True
    try:
        with urlopen(url, timeout=30) as response:
            if response.headers.get_content_maintype() != 'image':
                return False
            data = response.read()
    except OSError:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    partial = dest.with_suffix('.part')
    partial.write_bytes(data)
    partial.replace(dest)
    return True


def download_photos():
    """Download the photos not yet in MEDIA_ROOT/demo and return the ones on disk."""
    wanted = []  # (bucket, media path, url)
    for bucket, ids in (('female', FEMALE_PORTRAITS), ('male', MALE_PORTRAITS)):
        wanted += [(bucket, f'demo/portraits/{i}.jpg', PHOTO_URL.format(id=i, crop='faces')) for i in ids]
    for category, ids in SCENES.items():
        wanted += [(category, f'demo/scenes/{category}/{i}.jpg', PHOTO_URL.format(id=i, crop='entropy'))
                   for i in ids]

    root = Path(settings.MEDIA_ROOT)
    with ThreadPoolExecutor(max_workers=8) as pool:
        on_disk = list(pool.map(_fetch, [(url, root / path) for _, path, url in wanted]))

    photos = DemoPhotos()
    for (bucket, path, _), ok in zip(wanted, on_disk):
        if not ok:
            photos.missing += 1
        elif bucket in ('female', 'male'):
            getattr(photos, bucket).append(path)
        else:
            photos.scenes.setdefault(bucket, []).append(path)
    return photos


def _gender(display_name):
    first = (display_name or '').split(' ')[0]
    if first in FEMALE_NAMES:
        return 'female'
    if first in MALE_NAMES:
        return 'male'
    return 'any'


@transaction.atomic
def assign_photos(photos):
    """Give every demo account a portrait that matches its first name, and every
    demo host a gallery from its categories. Running it again changes nothing.

    Returns (accounts with a portrait, hosts with a gallery)."""
    portraits = {'female': photos.female, 'male': photos.male, 'any': photos.female + photos.male}
    turn = Counter()  # round-robin inside each pool, so neighbours rarely share a face
    users = list(User.objects.filter(username__startswith=SEED_PREFIX).order_by('id'))
    with_portrait = []
    for user in users:
        gender = _gender(user.display_name)
        pool = portraits[gender]
        if not pool:
            continue
        user.avatar = pool[turn[gender] % len(pool)]
        user.avatar_url = ''  # the old seed's links ignored the name's gender
        turn[gender] += 1
        with_portrait.append(user)
    User.objects.bulk_update(with_portrait, ['avatar', 'avatar_url'], batch_size=500)

    hosts = list(HostProfile.objects.filter(user__username__startswith=SEED_PREFIX))
    ProfilePhoto.objects.filter(host_profile__user__username__startswith=SEED_PREFIX).delete()
    gallery = []
    galleries = 0
    for host in hosts:
        categories = [c for c in normalize_categories(host.categories) if photos.scenes.get(c)]
        categories = categories or sorted(photos.scenes)
        if not categories:
            break
        rng = random.Random(host.pk)
        picked = []
        for n in range(GALLERY_SIZE):
            options = [p for p in photos.scenes[categories[n % len(categories)]] if p not in picked]
            if options:
                picked.append(rng.choice(options))
        gallery += [ProfilePhoto(host_profile=host, photo=path, order=n) for n, path in enumerate(picked)]
        galleries += 1
    ProfilePhoto.objects.bulk_create(gallery, batch_size=1000)
    return len(with_portrait), galleries
