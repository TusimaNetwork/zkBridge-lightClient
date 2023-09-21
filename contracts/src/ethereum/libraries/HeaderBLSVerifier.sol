pragma solidity 0.8.14;

import "./Pairing.sol";

library HeaderBLSVerifier {

    struct SignatureVerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct SignatureProof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    function signatureVerifyingKey() internal pure returns (SignatureVerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
            6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
            10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
            10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
            8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [11189806570539144736727012544656298041306137206388952077894435495341338625055,
            11858349594271760113337524322538902608009287667177178391464696310726879422067],
            [5595369512531394865406589446247079617010140216284237311327337258440181370157,
            18379371339796698120587917695047371560944479696904810575900438613279013654931]
        );
        vk.IC = new Pairing.G1Point[](35);

        vk.IC[0] = Pairing.G1Point(
            13438283153526239070838379159409825246703895230089526840814483072314913977983,
            16291730063905947425018400876105600537656457924790842220052692081289028256794
        );

        vk.IC[1] = Pairing.G1Point(
            1429938886066451034867026739198324202949956272687375478141651682569332075686,
            18806431884851308549797181858759261879020736928779385772720677127115677612462
        );

        vk.IC[2] = Pairing.G1Point(
            8335067696037666326793259821997699668324318011973475989945872747912505606957,
            13189566974829609492092448936972497141172587818722894443032826226520409729394
        );

        vk.IC[3] = Pairing.G1Point(
            21213708715712156866767777661977788277850580126695070238930328258638542993703,
            3877107115173683946579082727455205426400698917801428419580663904962445718889
        );

        vk.IC[4] = Pairing.G1Point(
            3748525012097900874070569260703250685904702680344177064892453012802172504741,
            8423811644339028185871468942997655026053600144354475441223034246188534241172
        );

        vk.IC[5] = Pairing.G1Point(
            11134530744751908086526008153074565319580828785779188828267782220600326743165,
            375912472296333214747479910788640389038161644029402170222317276851277282317
        );

        vk.IC[6] = Pairing.G1Point(
            18669683155676314400736103482876735832539064992855833590512079820697376832625,
            4147504453824255433256747426179685953315806543485215419388538515006411543511
        );

        vk.IC[7] = Pairing.G1Point(
            385560172380008767403272684055202310596864189235556057994215397687696080687,
            14596963844930874224691668769598658775310112038775643916321202991409712142374
        );

        vk.IC[8] = Pairing.G1Point(
            6471994225246937839694659547442669205729903722746005219843833567205280055155,
            1938045789275182618453800876789094859670398628923034252392072052577483681201
        );

        vk.IC[9] = Pairing.G1Point(
            20632000976241748017252057302421816585868281357537787775488144723478439549363,
            2445549694658321028124709883460204776759445020192364705136288061119923723738
        );

        vk.IC[10] = Pairing.G1Point(
            12766002908804030335033465302685342331816209010088333403688149114528965187214,
            14643685459236117538698635600410748469362688017818749468665639541159106461656
        );

        vk.IC[11] = Pairing.G1Point(
            20510048680791036740343627536284187728093468973039622995626194918504203711795,
            3270566863451302875472140807536509669207686686099815110074541975682238607424
        );

        vk.IC[12] = Pairing.G1Point(
            6600047304611185168169711529286102926727944673037538316136850542624164821160,
            14134230986748798202313617761637363125569948747861148801694949096977458868689
        );

        vk.IC[13] = Pairing.G1Point(
            19137996326497674907448424956747478578202778141546092035923958470352908229306,
            7984881466165223479027016481879920210277603709893792979055269407896152203253
        );

        vk.IC[14] = Pairing.G1Point(
            3481005874936573398374355492482181758981604007810877980206018229962661049205,
            981855150305594898224303660493365197253179914591639965076720150519984515269
        );

        vk.IC[15] = Pairing.G1Point(
            5198296937595783791864043076511066537316578343982812042120096654675668384796,
            1601279314402043168663040611139912304824589654515366478528124066492339865615
        );

        vk.IC[16] = Pairing.G1Point(
            8435958390020321687643099843717868117166967946921853822325139793002642462991,
            12328845416666837352080944330965640256157392591367801717452437326455143244820
        );

        vk.IC[17] = Pairing.G1Point(
            1012873840560905838578101386733145027952537294190702800696473854363011450622,
            13580006103452593788028871241714684846684820306297855652500655477991793836041
        );

        vk.IC[18] = Pairing.G1Point(
            4622684255372187521742007079114922515583326639671053144311130165601369069664,
            18950241556985359291473619032709273432443744870639240933077513772456732543484
        );

        vk.IC[19] = Pairing.G1Point(
            9322075717259048284144778010920463844962481572617680198969724873538545361742,
            1880065465685632668492093361238089726144071476289572804927527407881937990593
        );

        vk.IC[20] = Pairing.G1Point(
            4330704200057784984285238214760883322844698255146289754222975690959301938577,
            15568086689515796515319925875897634670707557693612654353192891764065028103095
        );

        vk.IC[21] = Pairing.G1Point(
            19702540893444333366775736781263373022749931959028694012791557423906262275531,
            20923463306275493047126320035047308602454191366815719864754220198907557550389
        );

        vk.IC[22] = Pairing.G1Point(
            5164667925583093544290844216735865871934833902020774988551159085155399786933,
            8226906020821293167132937027133777514225796523947055106538977547929993519050
        );

        vk.IC[23] = Pairing.G1Point(
            4684946447217829235489329481344881896066793957260069471436653198703003520254,
            9314190281160828770684229897354263955996548157175479271225490407999943684083
        );

        vk.IC[24] = Pairing.G1Point(
            12639483548511544767889481687232770012815858827021854229165122838439958698629,
            15890219997674598896408548173709679845432409882105194910691064212828711043985
        );

        vk.IC[25] = Pairing.G1Point(
            5131762414318912377517137526263328936082157367606573522194702864126319599373,
            8268345239020503668646787572241336087246492377391409096001840149454837125597
        );

        vk.IC[26] = Pairing.G1Point(
            18745415518447345683284721721581075349487649803655018712435473533410711535662,
            19908623832126320812366522922570102666173034198560749957596788947314071410085
        );

        vk.IC[27] = Pairing.G1Point(
            16807457275996067784364229174559204140840267946974692152522840791692650160265,
            18203483002801341910607430118104165779220737084213934937475995623473273959231
        );

        vk.IC[28] = Pairing.G1Point(
            8766709093497184166465308574903409264050435764685505650430880139237530206382,
            20675232749756979969493091641140086530918252654337378789443379415126511290827
        );

        vk.IC[29] = Pairing.G1Point(
            8942849026430713071891495679490265548212054361060361315477025317593612672691,
            1292286646422842030272398204363620203639822982358370843747671903215698914929
        );

        vk.IC[30] = Pairing.G1Point(
            2991478625949020518389154427348603511919270126792597800473000635640481885251,
            1730668326601810681136337092203764687763374756087832222233636705359386180907
        );

        vk.IC[31] = Pairing.G1Point(
            7933328460212850679300065376071217385811034880997511075544182323497475900718,
            5480214634558732585651558840829582633059652218936911468051350946073934282939
        );

        vk.IC[32] = Pairing.G1Point(
            5694705432093390774585763839149140327253976577768041279313620017377095200584,
            4780464564707006736800977063708732892012691534428604350370469730117042561612
        );

        vk.IC[33] = Pairing.G1Point(
            1858098361574168452341506620057746224977357949233359564065723900189497861160,
            20266189774664741870774971270155299605278185006897626472067814285550646131004
        );

        vk.IC[34] = Pairing.G1Point(
            2002668352095941445583604079204410504943596366638463056940905924870814229723,
            13406916168642651648493192962582752162175433734225557219247584661868589311576
        );

    }
    function verifySignature(uint[] memory input, SignatureProof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        SignatureVerifyingKey memory vk = signatureVerifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifySignatureProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[34] memory input
    ) public view returns (bool r) {
        SignatureProof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verifySignature(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}