import pathlib,subprocess,unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
class SteamOptions(unittest.TestCase):
    def check_rejected(self,web,message):
        result=subprocess.run(['cmake','-DCANIS_ENABLE_STEAM_INPUT=ON',f'-DCANIS_PLATFORM_WEB={web}','-DCANIS_STEAMWORKS_SDK=/nonexistent/canis-sdk','-P',str(ROOT/'canis/cmake/SteamInput.cmake')],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn(message,result.stdout+result.stderr)
    def test_web_rejected(self):self.check_rejected('ON','unavailable on web')
    def test_missing_sdk_explained(self):self.check_rejected('OFF','Set CANIS_STEAMWORKS_SDK')
if __name__=='__main__':unittest.main()
