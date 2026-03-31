// router/index.js
import { createRouter, createWebHistory } from 'vue-router';
import HomePage from '../pages/home/index.vue';
import MusicPage from '../pages/music/index.vue';
import MyCourseware from '../pages/courseware/index.vue';
import detailVue from '../pages/courseware/detail.vue';
import detail2Vue from '../pages/courseware/detail2.vue';
import VideoTutorial from '../pages/VideoTutorial/index.vue';
import SmartDictation from '../pages/SmartDictation/index.vue';
import SmartCampus from '../pages/SmartCampus/index.vue';
import MyNotes from '../pages/MyNotes/index.vue';
import MyCollection from '../pages/MyCollection/index.vue';
import PersonalCenter from '../pages/PersonalCenter/index.vue';
import HelpFeedback from '../pages/HelpFeedback/index.vue';
import login from '../pages/login/index.vue'
import register from '../pages/login/register.vue'
import forgetVue from '../pages/login/forget.vue'
import note_bg from '../pages/MyNotes/note_bg.vue'
import answerQuestionsVue from '../pages/home/answerQuestions.vue';
import campVue from '../pages/home/camp.vue';
import consultationVue from '../pages/home/consultation.vue';
import DictationVue from '../pages/home/Dictation.vue';
import mockVue from '../pages/home/mock.vue';
import musicTheoryVue from '../pages/home/musicTheory.vue';
import sightSingingVue from '../pages/home/sightSinging.vue';
import storeVue from '../pages/home/store.vue';
import musicVue from '../pages/home/music_play.vue';
import recordingVue from '../pages/recording/index.vue';
import voiceVue from '../pages/home/voice.vue';
import instrumentalVue from '../pages/home/instrumental.vue';
import theoryVue from '../pages/home/theory.vue';
// import videoVue from '../pages/VideoTutorial/video.vue';
import answerVue from '../pages/SmartDictation/answer.vue';
import answer2Vue from '../pages/SmartDictation/answer2.vue';
import answer3Vue from '../pages/SmartDictation/answer3.vue';
import overVue from '../pages/SmartDictation/over.vue';
import infoVue from '../pages/PersonalCenter/info.vue';
import fankuiVue from '../pages/PersonalCenter/fankui.vue';
import qrcodeVue from '../pages/PersonalCenter/qrcode.vue';
import campAnswerVue from '../pages/home/camp_answer.vue';
import campOverVue from '../pages/home/camp_over.vue';
import chatVue from '../pages/SmartCampus/chat.vue';
import consultationDetailVue from '../pages/home/consultationDetail.vue';
import noteDvue from '../pages/MyNotes/note.vue';
import answerEndDvue from '../pages/home/answer_end.vue';
import answerEnd2Dvue from '../pages/home/answer_end2.vue';
import verifiedVue from '../pages/PersonalCenter/verified.vue'
import setVue from '../pages/PersonalCenter/set.vue';
import xieyiVue from '../pages/PersonalCenter/xieyi.vue';
import xieyi2Vue from '../pages/PersonalCenter/xieyi2.vue';
import emailVue from '../pages/PersonalCenter/email.vue';
import personalAiVue from '../pages/AiChat/index.vue';
import AiSongVue from '../pages/AiSong/index.vue';
import schollPage from '../pages/home/school.vue';
import SmartSinging from '../pages/SmartSinging/index.vue';
import signRecordsVue from '../pages/SmartCampus/sign-records.vue';

const routes = [
    { path: '/', component: HomePage ,name:"home"},
	{ path: '/school', component: schollPage ,name:"school"},
    { path: '/music', component: MusicPage },
	{ path: '/courseware', component: MyCourseware },
    { path: '/video-tutorial', component: VideoTutorial ,name:'video'},
    { path: '/smart-dictation', component: SmartDictation ,name:"smartDictation"},
    { path: '/smart-campus', component: SmartCampus ,name:"smart-campus"},
    { path: '/smart-singing', component: SmartSinging, name: "smart-singing" },
    { path: '/my-notes', component: MyNotes,name:"note" },
    { path: '/my-collection', component: MyCollection },
    { path: '/personal-center', component: PersonalCenter ,name:"personal"},
    { path: '/help-feedback', component: HelpFeedback },
	{path:'/login',component:login,name:"login"},
	{path:'/note_bg',component:note_bg,name:'note_bg'},
	{path:'/answerQuestions',component:answerQuestionsVue,name:'answerQuestions'},
	{path:'/camp',component:campVue,name:'camp'},
	{path:'/consultation',component:consultationVue,name:'consultation'},
	{path:'/Dictation',component:DictationVue,name:'Dictation'},
	{path:'/mock',component:mockVue,name:'mock'},
	{path:'/musicTheory',component:musicTheoryVue,name:'musicTheory'},
	{path:'/sightSinging',component:sightSingingVue,name:'sightSinging'},
	{path:'/store',component:storeVue,name:'store'},
	{path:'/musicPlay',component:musicVue,name:'music'},
	{path:'/recording',component:recordingVue,name:'recording'},
	{path:'/voice',component:voiceVue,name:'voice',meta:{keepAlive:true}},
	{path:'/instrumental',component:instrumentalVue,name:'instrumental'},
	{path:'/theory',component:theoryVue,name:'theory'},
	// {path:'/video',component:videoVue,name:'video'},
	{path:'/register',component:register,name:'register'},
	{path:'/forget',component:forgetVue,name:'forget'},
	{path:'/answer',component:answerVue,name:'answer'},
	{path:'/answer2',component:answer2Vue,name:'answer2'},
	{path:'/answer3',component:answer3Vue,name:'answer3'},
	{path:'/over',component:overVue,name:'over'},
	{path:'/detail',component:detailVue,name:'detail'},
	{path:'/detail2',component:detail2Vue,name:'detail2'},
	{path:'/info',component:infoVue,name:'info'},
	{path:'/fankui',component:fankuiVue,name:'fankui'},
	{path:'/qrcode',component:qrcodeVue,name:'qrcode'},
	{path:'/camp_answer',component:campAnswerVue,name:'camp_answer'},
	{path:'/camp_over',component:campOverVue,name:'camp_over'},
	{path:'/chat',component:chatVue,name:'chat'},
	{path:'/consultationDetail',component:consultationDetailVue,name:'consultationDetail'},
	{path:'/noteDetail',component:noteDvue,name:'noteDetail'},
	{path:'/answerEnd',component:answerEndDvue,name:'answerEnd'},
	{path:'/answerEnd2',component:answerEnd2Dvue,name:'answerEnd2'},
	{path:'/verifie',component:verifiedVue,name:'verified'},
	{path:'/set',component:setVue,name:'set'},
	{path:'/xieyi',component:xieyiVue,name:'xieyi'},
	{path:'/xieyi2',component:xieyi2Vue,name:'xieyi2'},
	{path:'/personal-Ai',component:personalAiVue,name:'personal-Ai'},
	{path:'/email',component:emailVue,name:'email'},
	{path:"/AiSong",component:AiSongVue,name:"AiSong"},
	{
		path: '/smart-campus',
		name: 'smart-campus',
		component: SmartCampus,
		children: [
			{
				path: 'sign-records',
				name: 'sign-records',
				component: () => import('@/pages/SmartCampus/sign-records.vue')
			}
		]
	}
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

export default router;
