mod RandomUtil {

    pub def pick(l: List[a]): Option[a] \ Math.Random =
        let len = List.length(l);
        if (len == 0) None
        else
            let r = Math.Random.randomFloat64();
            let idx = Float64.truncateToInt32(Float64.floor(r * Int32.toFloat64(len)));
            List.nth(idx, l)

}
